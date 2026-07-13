# Lab 2 — Variables, Locals & Outputs

**Level:** Medium · **Time:** ~30 min · **Azure needed:** Yes (fallback below)

Turn Lab 1's hard-coded config into **reusable** code: drive the resource group from inputs,
compute a name with `locals`, and return a value with `output`.

## What you'll practice
- Declaring input **variables** with types and defaults.
- Building a value once with **locals**.
- Returning results with **outputs**.
- Overriding a variable at the command line — no code change needed.

## Prerequisites
- Finished Lab 1 (or comfortable with `init/plan/apply`).
- `az login` done.

---

## Steps

### 1. Start from a fresh folder with three files

`variables.tf`
```hcl
variable "location" {
  type    = string
  default = "East US"
}

variable "project" {
  type    = string
  default = "intern-demo"
}
```

`main.tf`
```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.116" }
  }
}

provider "azurerm" {
  features {}
}

locals {
  # compute the name once, reuse it anywhere
  rg_name = "rg-${var.project}"
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
}
```

`outputs.tf`
```hcl
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
```

### 2. Init and apply
```bash
terraform init
terraform apply    # type yes
```
At the end, Terraform prints:
```
Outputs:
resource_group_name = "rg-intern-demo"
```

### 3. Read outputs any time
```bash
terraform output
terraform output -raw resource_group_name
```

### 4. Change region with a flag — no code edit
```bash
terraform apply -var="location=West US 2"
```
Read the plan: only the location changes. This is the whole point of variables.

### 5. Destroy
```bash
terraform destroy
```

---

## Done when
The same config deploys to a different region just by passing a different `-var` — you never
edited the `.tf` files.

## No Azure? Fallback
Use `local_file` and vary the filename/content from variables:
```hcl
variable "name" { default = "notes" }
resource "local_file" "f" {
  filename = "${path.module}/${var.name}.txt"
  content  = "Project: ${var.name}"
}
output "path" { value = local_file.f.filename }
```
Try `terraform apply -var="name=demo2"`.

## What you learned
- **Variables** are inputs (from defaults, `-var`, `.tfvars`, or env `TF_VAR_*`).
- **Locals** are computed inside the config (great for names/tags).
- **Outputs** surface results and are how modules hand data back (Lab 5).
