terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
}

# Free/basic App Service Plan
resource "azurerm_service_plan" "app_plan" {
  name                = "${var.project_name}-${var.environment}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type  = "Linux"
  sku_name = var.app_service_sku # F1 = Free, B1 = Basic
}

resource "azurerm_linux_web_app" "web_app" {
  name                = "${var.project_name}-${var.environment}-web-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.app_plan.id

  https_only = true

  site_config {
    always_on = var.app_service_sku == "F1" ? false : true

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "ENVIRONMENT"                    = var.environment
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"

    # Your chatbot backend can read these values
    "AZURE_OPENAI_ENDPOINT"    = azurerm_cognitive_account.openai.endpoint
    "AZURE_OPENAI_API_KEY"     = azurerm_cognitive_account.openai.primary_access_key
    "AZURE_OPENAI_DEPLOYMENT"  = azurerm_cognitive_deployment.chat_model.name
    "AZURE_OPENAI_API_VERSION" = var.openai_api_version
  }

  identity {
    type = "SystemAssigned"
  }
}

# Azure OpenAI / Foundry LLM API resource
resource "azurerm_cognitive_account" "openai" {
  name                = "${var.project_name}-${var.environment}-openai-${random_string.suffix.result}"
  location            = var.openai_location
  resource_group_name = azurerm_resource_group.rg.name

  kind     = "OpenAI"
  sku_name = "S0"

  custom_subdomain_name = "${var.project_name}-${var.environment}-openai-${random_string.suffix.result}"

  public_network_access_enabled = true

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Chat model deployment
resource "azurerm_cognitive_deployment" "chat_model" {
  name                 = "chat-model"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }
  sku {
    name     = var.openai_deployment_sku
    capacity = var.openai_capacity
  }
}

resource "azurerm_role_assignment" "web_app_openai_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app.web_app.identity[0].principal_id
}