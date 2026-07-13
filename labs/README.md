# Terraform + GitHub Actions — Lab Workbook

Hands-on labs that go with the *Terraform / Infrastructure as Code* training deck.
Do them in order — each one builds on the last.

| Lab | Topic | Level | Time | Azure needed? |
|---|---|---|---|---|
| [Lab 0](lab-0-hello-github-actions.md) | Hello GitHub Actions (trigger a job, print output) | Easy | ~15 min | No |
| [Lab 1](lab-1-first-apply.md) | Your first apply — create a resource group | Easy | ~20 min | Yes* |
| [Lab 2](lab-2-variables-locals-outputs.md) | Variables, locals & outputs | Medium | ~30 min | Yes* |
| [Lab 3](lab-3-remote-state.md) | Remote state on Azure Storage | Hard | ~40 min | Yes |
| [Lab 4](lab-4-data-sources-and-dependencies.md) | Data sources + dependencies | Medium–Hard | ~35 min | Yes* |
| [Lab 5](lab-5-build-a-module.md) | Build & reuse a module | Hard | ~40 min | Yes* |
| **Capstone** | End-to-end: Terraform → GitHub Actions → Azure | Very hard | ~90 min | Yes |

\* Every Terraform lab has a **"No Azure?"** fallback using the free `local_file`/`random`
providers, so you can practice the same ideas with no cloud account.

## Before you start

Install these once:
- [Terraform](https://developer.hashicorp.com/terraform/downloads) — check with `terraform -version`
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) — check with `az version`
- A code editor (VS Code + the HashiCorp Terraform extension is nice)
- A GitHub account (for Lab 0 and the Capstone)

Then sign in to Azure once: `az login` and `az account set --subscription "<your-sub>"`.

## The golden rules (true for every lab)

1. **Always read the `plan`** before you `apply`.
2. **Never commit** `*.tfstate`, `.terraform/`, or `*.tfvars` with secrets (there's a `.gitignore` for this).
3. **Always `terraform destroy`** at the end of a lab so you don't get billed.
4. Storage account names must be **globally unique and lowercase** — if you get a name clash, add a few random digits.

## The Capstone

The capstone (deploy real infrastructure through a GitHub Actions pipeline) is documented in
the main repository **`README.md`** — it's the full Terraform → OIDC → Azure walkthrough.
Do Lab 0 and Labs 1–5 first; the capstone ties them all together.
