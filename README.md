# Terraform → GitHub Actions → Azure (Hands-on Guide) 


- dummy change

This repo contains a small Terraform configuration (`main.tf`, `variables.tf`, `outputs.tf`).
It works when you run it **locally**. This guide walks you through making it run in
**GitHub Actions** so that every push provisions the resources in **Azure automatically**.

Follow the steps in order. Commands are written for **PowerShell** (Windows). If you use
bash/macOS/Linux, the only difference is the line-continuation character: use `\` instead of
the backtick `` ` ``.

---

## What you'll learn

- Why "it works on my laptop" is not enough for CI (auth + state).
- How to let GitHub Actions log in to Azure **without any password** (OIDC).
- How to keep Terraform state in **Azure Storage** so runs are repeatable.
- How to wire up a pipeline that runs `plan` on pull requests and `apply` on `main`.

## The two things that change when you move to CI

| | On your laptop | In GitHub Actions |
|---|---|---|
| **Who am I?** (auth) | You, via `az login` | A **service principal** the runner logs in as (we use OIDC) |
| **What have I built?** (state) | A `terraform.tfstate` file on your disk | A **remote state** blob in Azure Storage (the runner is wiped after each run) |

Almost every failure below traces back to one of these two. Set them up once and the pipeline just works.

## Prerequisites

- An Azure subscription you can deploy into.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed (`az version`).
- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed (`terraform -version`).
- This repository pushed to **your** GitHub account.
- Permission to create an app registration in your Azure AD tenant. *(In a locked-down company
  tenant you may not have this — see [Troubleshooting](#troubleshooting).)*

Throughout, replace these placeholders with your own values:

- `<OWNER>/<REPO>` → your GitHub repo, e.g. `AashikSharif/Terraform-demo`
- `<STATE_SA>` → a globally-unique Storage account name for state (3–24 lowercase letters/numbers)

---

## Step 1 — Confirm it runs locally

```powershell
az login
terraform init
terraform plan
```
If `plan` succeeds, your config is fine and you're ready to automate it.

## Step 2 — Create the remote state storage (once)

State cannot live on the disposable runner, so put it in Azure Storage.

```powershell
$StateRg = "rg-tfstate"
$StateSa = "<STATE_SA>"        # must be globally unique, lowercase
az group create -n $StateRg -l eastus
az storage account create -n $StateSa -g $StateRg -l eastus --sku Standard_LRS --min-tls-version TLS1_2
az storage container create -n tfstate --account-name $StateSa --auth-mode login
```
Write down `<STATE_SA>` — you'll use it in Steps 4 and 6.

> Already have a state storage account? Reuse it — just make sure it has a container named `tfstate`.

## Step 3 — Create the Azure login for GitHub (OIDC, passwordless)

```powershell
$Repo = "<OWNER>/<REPO>"       # your GitHub repo, NOT your local folder name

# 1) one app registration + service principal
$AppId = az ad app create --display-name "github-oidc-$($Repo.Split('/')[1])" --query appId -o tsv
az ad sp create --id $AppId
Start-Sleep -Seconds 20        # wait for Azure AD to replicate before assigning a role

# 2) federated credentials: main branch (apply) + pull requests (plan)
#    NOTE the ${Repo} braces — without them PowerShell reads "$Repo:ref" as a scoped
#    variable and silently inserts nothing. This is the #1 setup mistake.
@"
{ "name":"gh-main","issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:${Repo}:ref:refs/heads/main","audiences":["api://AzureADTokenExchange"] }
"@ | Out-File -Encoding ascii fic-main.json
az ad app federated-credential create --id $AppId --parameters "@fic-main.json"

@"
{ "name":"gh-pr","issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:${Repo}:pull_request","audiences":["api://AzureADTokenExchange"] }
"@ | Out-File -Encoding ascii fic-pr.json
az ad app federated-credential create --id $AppId --parameters "@fic-pr.json"
```

Verify the subjects are complete and match your repo exactly:
```powershell
az ad app federated-credential list --id $AppId --query "[].{name:name, subject:subject}" -o table
```
Expected:
```
gh-main  repo:<OWNER>/<REPO>:ref:refs/heads/main
gh-pr    repo:<OWNER>/<REPO>:pull_request
```

## Step 4 — Give the identity permission to deploy

```powershell
$SubId = az account show --query id -o tsv
az role assignment create --assignee $AppId --role "Contributor" --scope "/subscriptions/$SubId"
```

**Contributor** is enough to create most resources *and* to read the state-storage key.

> ⚠️ **Does your `main.tf` create an `azurerm_role_assignment` or a Key Vault access policy?**
> Then Contributor is **not** enough — creating role assignments needs **Owner** or
> **User Access Administrator**. Use `--role "Owner"` instead. If you can't get that in a
> company tenant, see [Troubleshooting → AuthorizationFailed](#authorizationfailed-on-a-role-assignment).

## Step 5 — Add three GitHub repository secrets

Print the values:
```powershell
Write-Host "AZURE_CLIENT_ID       = $AppId"
Write-Host "AZURE_TENANT_ID       = $(az account show --query tenantId -o tsv)"
Write-Host "AZURE_SUBSCRIPTION_ID = $SubId"
```
Add them in GitHub: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | the app (client) ID |
| `AZURE_TENANT_ID` | your tenant ID |
| `AZURE_SUBSCRIPTION_ID` | your subscription ID |

## Step 6 — Point Terraform at the remote state

Add this block to `main.tf` (or merge the `backend` line into your existing `terraform {}` block):
```hcl
terraform {
  backend "azurerm" {}
}
```
It's intentionally empty — the values are passed in by the workflow.

**If you already ran `terraform apply` locally**, upload that existing state so CI doesn't try to
recreate everything:
```powershell
terraform init -migrate-state `
  -backend-config="resource_group_name=rg-tfstate" `
  -backend-config="storage_account_name=<STATE_SA>" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=demo.tfstate"
```
Answer **yes** to copy state. *(If your local run was just a test, run `terraform destroy`
locally instead and skip this — CI will build fresh.)*

## Step 7 — Add the workflow

Create `.github/workflows/terraform.yml` with the content below. Change **one** line:
`BACKEND_SA` → your `<STATE_SA>`.

```yaml
name: Terraform

on:
  push:
    branches: ["main"]
  pull_request:
  workflow_dispatch:

permissions:
  id-token: write      # required for OIDC login to Azure
  contents: read

env:
  ARM_USE_OIDC: "true"
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

  BACKEND_RG: rg-tfstate
  BACKEND_SA: <STATE_SA>          # <-- change this
  BACKEND_CONTAINER: tfstate
  BACKEND_KEY: demo.tfstate

jobs:
  terraform:
    name: Terraform
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.9.5"

      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="resource_group_name=${BACKEND_RG}" \
            -backend-config="storage_account_name=${BACKEND_SA}" \
            -backend-config="container_name=${BACKEND_CONTAINER}" \
            -backend-config="key=${BACKEND_KEY}"

      - name: Terraform Format (non-blocking)
        run: terraform fmt -check -recursive || echo "::warning::run 'terraform fmt'"

      - name: Terraform Plan
        run: terraform plan -input=false -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -input=false -auto-approve tfplan
```

## Step 8 — Push and watch it run

```powershell
git add .
git commit -m "Run Terraform in GitHub Actions (Azure OIDC + remote state)"
git push origin main
```
Open the **Actions** tab and follow the run: **login → init → plan → apply**.

- Open a **pull request** instead → the run stops after `plan` (a safe preview).
- Push to **main** → it runs `apply`.
- If you migrated state in Step 6, the first `plan` should say **"No changes"** — that's your confirmation everything is wired correctly.

---

## Troubleshooting

These are the real errors you're most likely to hit, and the fix for each.

### `terraform fmt -check` — "exited with code 3"
Your `.tf` files aren't formatted. Run `terraform fmt` locally, commit, push. (The workflow above
only warns instead of failing, so this won't block you — but format anyway.)

### The workflow does nothing with Azure / asks for a Terraform Cloud token
You're using GitHub's **Terraform Cloud** starter template. Replace it with the `terraform.yml`
in Step 7 — that one does Azure OIDC and uses the Azure Storage backend.

### `AADSTS70021: No matching federated identity record found`
The federated credential `subject` doesn't match the run. Check:
1. Subjects are complete (Step 3 verify). A common cause is the missing `${Repo}` braces in PowerShell.
2. The subject uses your **GitHub repo** name (`<OWNER>/<REPO>`), not your local folder name.
3. The workflow has `permissions: id-token: write`.

### `A resource with the ID ... already exists — needs to be imported`
CI state is empty, so Terraform tried to recreate something that already exists. This means your
local state wasn't shared with CI. Either:
- **Fresh start:** delete the resources (`az group delete -n <your-rg> --yes`) and let CI build them, or
- **Keep them:** run the `terraform init -migrate-state` from Step 6 to upload your local state.

### `AuthorizationFailed` on a role assignment
`... does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'`
Your `main.tf` creates a role assignment, which **Contributor can't do**. Options, best first:
1. Grant the identity **Owner** (or **User Access Administrator**):
   `az role assignment create --assignee $AppId --role "Owner" --scope "/subscriptions/$SubId"`
2. Can't get subscription-level rights? Scope it to just your target RG:
   `... --scope "/subscriptions/$SubId/resourceGroups/<your-rg>"`
3. Can't assign roles at all? **Remove the `azurerm_role_assignment` block** from `main.tf`
   (`terraform state rm <that.resource>` if it was partly created) and create that assignment by
   hand once with `az role assignment create`, or switch that service to **API-key** auth instead
   of managed identity.

### `Terraform Init` fails on the backend (auth / storage key)
Some tenants disable storage-account key access. Grant the identity data access to the state account:
```powershell
$SaId = az storage account show -n <STATE_SA> -g rg-tfstate --query id -o tsv
az role assignment create --assignee $AppId --role "Storage Blob Data Contributor" --scope $SaId
```

### A new `random_string` suffix appears every run
Same root cause as "already exists" — CI has no state. Fix the remote backend / state migration (Step 6).

---

## Which resource group is which?

If you see several, don't mix them up:

| Resource group | Purpose | Safe to delete? |
|---|---|---|
| **your deploy RG** (the one in `main.tf`) | The resources this Terraform creates | Yes — this is your practice target |
| **`rg-tfstate`** | Holds the state storage account | **No** — deleting it loses your state |
| any others | Other projects | Leave alone |

## Cleanup (avoid surprise costs)

These create real, billable resources. When you're done practicing:
```powershell
terraform destroy    # locally, with the same -backend-config flags used in init
```
or delete your deploy resource group in the Portal. Do **not** delete `rg-tfstate` unless you're
finished with the whole exercise.

---

## Optional level-up: approval before production

The setup above uses one identity that can both plan and apply. For a more realistic, safer flow,
split it into two identities and require a human to approve `apply`:
- a **read-only** app for `plan` (repo secrets),
- a **read/write** app for `apply`, tied to a protected GitHub **Environment** (e.g. `production`)
  with required reviewers.

See Microsoft's guide: *Deploy to Azure with IaC and GitHub Actions*
(`learn.microsoft.com/devops/deliver/iac-github-actions`).
