# Lab 1 — Your First Apply (Local → Azure)

**Level:** Easy · **Time:** ~25 min · **Azure needed:** Part A no · Part B yes

You'll learn the Terraform workflow **twice**. First with a **local** resource that needs no
cloud account, so you can focus on `init → plan → apply → destroy`. Then you'll change **only
the provider** and use the exact same commands to create a **real Azure resource group** —
proving the workflow is the same no matter what you're building.

## What you'll practice
- The four core commands with zero setup (local provider).
- That **providers** are pluggable — swap the provider, keep the workflow.
- Creating and destroying a real Azure resource.

## Prerequisites
- Terraform installed (`terraform -version`).
- For **Part B only:** Azure CLI installed and `az login` done.

---

# Part A — A local resource (no account needed)

### 1. Make a project folder
```bash
mkdir tf-lab1 && cd tf-lab1
```

### 2. Create `main.tf` using the `local` provider
```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# The local provider needs no credentials at all.
resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"
  content  = "Hello from Terraform! This file was created by 'terraform apply'.\n"
}
```

### 3. Initialize (downloads the `local` provider plugin)
```bash
terraform init
```

### 4. Preview — read every line
```bash
terraform plan
```
You'll see `Plan: 1 to add` and the file it will create.

### 5. Apply
```bash
terraform apply      # type yes
```
Now open `hello.txt` — Terraform created it. (`cat hello.txt` or open it in your editor.)

### 6. Destroy
```bash
terraform destroy    # type yes
```
`hello.txt` is deleted. You just ran the **entire Terraform loop** with no cloud account.

> **Pause and notice:** `init` set things up, `plan` changed nothing, `apply` made it real,
> `destroy` cleaned up. That loop is identical for every provider — including Azure, next.

---

# Part B — Change the provider to Azure

Now you'll keep the same workflow but point Terraform at Azure instead of your disk.

### 7. Sign in to Azure
```bash
az login
az account set --subscription "<your-sub>"
```

### 8. Replace the contents of `main.tf`
Swap the `local` provider for `azurerm`, and the file for a **resource group**:
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }
}

provider "azurerm" {
  features {}          # required for azurerm, even when empty
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-lab1-demo"
  location = "East US"
}
```

### 9. Re-initialize (you changed providers, so init must run again)
```bash
terraform init
```
> **Why again?** `init` downloads provider plugins. You removed `local` and added `azurerm`,
> so Terraform needs to fetch the new plugin. Any time `required_providers` changes, re-run `init`.

### 10. Plan and apply — same commands as Part A
```bash
terraform plan       # read it: Plan: 1 to add
terraform apply      # type yes
```

### 11. Verify in Azure
[Azure Portal](https://portal.azure.com) → **Resource groups** → you'll see `rg-lab1-demo`.
Or:
```bash
az group show -n rg-lab1-demo -o table
```

### 12. Destroy
```bash
terraform destroy    # type yes
```
The resource group disappears from the Portal.

---

## Done when
- Part A created and destroyed `hello.txt` with **no account**, and
- Part B created and destroyed `rg-lab1-demo` in Azure — using the **same four commands**.

## What you learned
- **Providers are plugins.** `local` writes files with no auth; `azurerm` talks to Azure and
  needs `az login` plus the mandatory `provider "azurerm" { features {} }` block.
- The **workflow never changes**: `init → plan → apply → destroy`, whatever you're provisioning.
- **`init` must re-run** whenever you add or change a provider.
- A "project" is just a folder of `.tf` files.

## Cleanup
Make sure you ran `terraform destroy` in Part B so the Azure resource group is gone (it's free
here, but get in the habit). Part A leaves nothing behind.
