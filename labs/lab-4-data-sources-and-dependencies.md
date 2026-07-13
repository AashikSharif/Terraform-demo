# Lab 4 — Data Sources + Dependencies

**Level:** Medium–Hard · **Time:** ~35 min · **Azure needed:** Yes (fallback below)

Learn how Terraform figures out the **order** to build things (implicitly, from references)
and how to **force** an order when needed (`depends_on`). Also read existing infrastructure
with a **data source**.

## What you'll practice
- Implicit dependencies — a reference *is* a dependency.
- Explicit dependencies — `depends_on` when there's no reference.
- Reading existing resources with a `data` block.

## Prerequisites
- Comfortable with `init/plan/apply`.
- `az login` done.

---

## Steps

### 1. Create a resource group and a storage account that references it
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

resource "azurerm_resource_group" "rg" {
  name     = "rg-lab4-demo"
  location = "East US"
}

resource "azurerm_storage_account" "sa" {
  name                     = "lab4sa<yourinitials><digits>"   # globally unique, lowercase, <=24
  resource_group_name      = azurerm_resource_group.rg.name    # <-- reference = implicit dependency
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

### 2. Plan and note the order
```bash
terraform init
terraform plan
```
Because the storage account **references** `azurerm_resource_group.rg`, Terraform knows the
group must exist first — you didn't tell it to; the reference did.

### 3. Apply, then watch the order in the output
```bash
terraform apply    # type yes
```
The resource group is created before the storage account.

### 4. Add an explicit dependency
Add a container that has no direct reference to force ordering with `depends_on`:
```hcl
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.sa]   # explicit: "make sure the account exists first"
}
```
Run `terraform apply` again and note the ordering.

### 5. (Optional) Read something that already exists with a data source
Instead of creating the group, you can *read* one that already exists:
```hcl
data "azurerm_resource_group" "existing" {
  name = "rg-lab1-demo"   # e.g. from an earlier lab
}
# then use data.azurerm_resource_group.existing.location, etc.
```
A `data` block is **read-only** — it looks things up, it doesn't create them.

### 6. Destroy
```bash
terraform destroy
```

---

## Done when
Terraform creates the resource group **before** the storage account without you specifying an
order — the reference did it.

## No Azure? Fallback
Use `random` + `local_file`: make one resource reference another to show ordering.
```hcl
resource "random_pet" "name" {}
resource "local_file" "f" {
  filename = "${path.module}/${random_pet.name.id}.txt"   # references random_pet => implicit order
  content  = "created after the random name"
}
```

## What you learned
- **`resource`** creates and manages something; **`data`** only reads existing things.
- A reference between resources creates an **implicit** dependency (preferred).
- Use **`depends_on`** only when there's an ordering need but no reference.
