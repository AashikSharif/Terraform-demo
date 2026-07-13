# Lab 1 — Your First Apply

**Level:** Easy · **Time:** ~20 min · **Azure needed:** Yes (fallback below)

Prove your setup works end to end by creating **one real Azure resource** — a resource group —
and running the full `init → plan → apply → destroy` loop.

## What you'll practice
- The four core Terraform commands.
- Reading a `plan` before applying.
- Confirming a resource in the Azure Portal, then cleaning it up.

## Prerequisites
- Terraform and Azure CLI installed.
- Signed in: `az login` then `az account set --subscription "<your-sub>"`.

---

## Steps

### 1. Make a project folder
```bash
mkdir tf-lab1 && cd tf-lab1
```

### 2. Create `main.tf`
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
  features {}          # required, even when empty
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-lab1-demo"
  location = "East US"
}
```

### 3. Initialize (downloads the azurerm provider)
```bash
terraform init
```

### 4. Preview the change — read every line
```bash
terraform plan
```
You should see `Plan: 1 to add, 0 to change, 0 to destroy` and the resource group's details.

### 5. Apply it
```bash
terraform apply
```
Type **yes** when prompted.

### 6. Verify in the Portal
Go to the [Azure Portal](https://portal.azure.com) → **Resource groups** → you should see
`rg-lab1-demo`. (Or run `az group show -n rg-lab1-demo -o table`.)

### 7. Destroy it
```bash
terraform destroy
```
Type **yes**. The resource group disappears from the Portal.

---

## Done when
`rg-lab1-demo` appears in the Portal after `apply`, and is gone after `destroy`.

## No Azure? Fallback
Swap the provider/resource for the `local_file` provider — same four commands, no account:
```hcl
resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"
  content  = "Terraform created this file!"
}
```
`init → plan → apply` creates `hello.txt`; `destroy` deletes it.

## What you learned
- A "project" is just a folder of `.tf` files.
- `plan` changes nothing; `apply` makes it real; `destroy` cleans up.
- `provider "azurerm" { features {} }` is mandatory boilerplate.
