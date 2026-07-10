output "web_app_url" {
  value = "https://${azurerm_linux_web_app.web_app.default_hostname}"
}

output "azure_openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "azure_openai_deployment_name" {
  value = azurerm_cognitive_deployment.chat_model.name
}

output "azure_openai_key" {
  value     = azurerm_cognitive_account.openai.primary_access_key
  sensitive = true
}