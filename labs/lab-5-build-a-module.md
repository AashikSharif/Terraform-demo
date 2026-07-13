# Lab 5 — Build & Reuse a Module

**Level:** Hard · **Time:** ~40 min · **Azure needed:** Yes (fallback below)

Package infrastructure into a **reusable module** (like a function for infrastructure) and call
it twice with different inputs.

## What you'll practice
- Creating a module with its own variables, resources, and outputs.
- Calling a module with `source` and inputs.
- Reusing one definition to build multiple environments.

## Prerequisites
- Comfortable with variables/outputs (Lab 2).
- `az login` done.

---

## Steps

### 1. Create the module folder
```
tf-lab5/
├─ main.tf                 (root)
└─ modules/
   └─ rg/
      ├─ variables.tf
      ├─ main.tf
      └─ outputs.tf
```

`modules/rg/variables.tf`
```hcl
variable "name" {}
variable "location" {
  default = "East US"
}
```

`modules/rg/main.tf`
```hcl
resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
}
```

`modules/rg/outputs.tf`
```hcl
output "id" {
  value = azurerm_resource_group.this.id
}
```

### 2. Call the module twice from the root
`main.tf` (root)
```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.116" }
  }
}
provider "azurerm" {
  features {}
}

module "dev" {
  source = "./modules/rg"
  name   = "rg-dev"
}

module "prod" {
  source   = "./modules/rg"
  name     = "rg-prod"
  location = "West US 2"
}

# use a module's output at the root
output "dev_rg_id" {
  value = module.dev.id
}
```

### 3. Init — this registers the module
```bash
terraform init      # note: 'Initializing modules...'
```
> Any time you add or change a module `source`, you must run `terraform init` again.

### 4. Plan and apply
```bash
terraform plan      # shows module.dev + module.prod resource groups
terraform apply     # type yes
```
Both `rg-dev` and `rg-prod` are created from the **same** module definition.

### 5. See the output and destroy
```bash
terraform output dev_rg_id
terraform destroy
```

---

## Done when
One module definition produces **both** a dev and a prod resource group.

## No Azure? Fallback
Build a `local_file` module and instantiate it twice with different filenames:
```hcl
# modules/note/main.tf
variable "name" {}
resource "local_file" "f" {
  filename = "${path.root}/${var.name}.txt"
  content  = "module made ${var.name}"
}
# root
module "a" { source = "./modules/note"  name = "alpha" }
module "b" { source = "./modules/note"  name = "beta" }
```

## What you learned
- A module is a folder of `.tf` files you reuse — pass **inputs**, get **outputs**.
- Reference module outputs as `module.<name>.<output>`.
- `terraform init` must re-run when a module is added.
- The public **Terraform Registry** has ready-made modules you can call the same way.
