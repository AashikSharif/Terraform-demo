# Lab 3 — Remote State on Azure Storage

**Level:** Hard · **Time:** ~40 min · **Azure needed:** Yes

Move Terraform state off your laptop into **Azure Storage** — the way teams (and CI pipelines)
do it, with locking so two people can't clobber each other.

## What you'll practice
- Creating a storage account + blob container for state.
- Adding an `azurerm` **backend** and **migrating** local state to it.
- Seeing that state is now remote (and locked during applies).

## Prerequisites
- Finished Lab 2 (you have a small config that applies cleanly).
- `az login` done.

---

## Steps

### 1. Create the state storage (once)
Pick a **globally unique, lowercase** storage account name (add digits if it clashes).
```bash
az group create -n rg-tfstate -l eastus
az storage account create -n tfstate<yourinitials><digits> -g rg-tfstate -l eastus \
  --sku Standard_LRS --min-tls-version TLS1_2
az storage container create -n tfstate --account-name tfstate<yourinitials><digits> --auth-mode login
```

### 2. Add a backend block to `main.tf`
Add this inside (or as) your `terraform {}` block:
```hcl
terraform {
  backend "azurerm" {}
}
```
Leaving it empty lets you pass the values at init time (so nothing environment-specific is
committed).

### 3. Initialize the backend and migrate state
```bash
terraform init -migrate-state \
  -backend-config="resource_group_name=rg-tfstate" \
  -backend-config="storage_account_name=tfstate<yourinitials><digits>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=lab3.tfstate"
```
Terraform detects your existing **local** state and asks to copy it up — type **yes**.

### 4. Confirm the state blob exists
```bash
az storage blob list --account-name tfstate<yourinitials><digits> \
  --container-name tfstate --auth-mode login -o table
```
You should see `lab3.tfstate`.

### 5. Prove state is remote
Delete your local state files and run a plan — it still works, because the state lives in Azure now:
```bash
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan     # No changes — state came from the blob
```

### 6. See the lock (optional)
Start an `apply`, and while it's mid-run, open a second terminal and run `terraform plan`.
The second one waits: *"Acquiring state lock…"* — that's Azure Storage preventing two writers.

### 7. Destroy
```bash
terraform destroy
```

---

## Done when
`terraform init` reports the state migrated, and `plan` still works after you delete the local
state file.

## No Azure? Fallback
No account? Read the [azurerm backend docs](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
and write, in your own words, the steps to migrate state and how locking prevents two
simultaneous applies.

## Common snags
- **`init` fails on the backend / storage key** — your account may block key access; from CI
  you'd grant the identity `Storage Blob Data Contributor`. Locally, `--auth-mode login` uses you.
- **Stale lock** ("state blob is already locked") — break it with
  `az storage blob lease break --blob-name lab3.tfstate --container-name tfstate --account-name <sa> --auth-mode key`.

## What you learned
- Local state doesn't work for teams or CI — remote state is shared and lockable.
- `-migrate-state` uploads existing state instead of starting blank.
- This backend is exactly what the Capstone/CI pipeline uses.
