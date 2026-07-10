variable "project_name" {
  type    = string
  default = "chatbot"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "westus2"
}

variable "openai_location" {
  type    = string
  default = "eastus"
}

variable "app_service_sku" {
  type    = string
  default = "F1"
}

variable "openai_deployment_name" {
  type    = string
  default = "chat-model"
}

variable "openai_model_name" {
  type    = string
  default = "gpt-5-nano"
}

variable "openai_model_version" {
  type    = string
  default = "2025-08-07"
}

variable "openai_deployment_sku" {
  type    = string
  default = "GlobalStandard"
}

variable "openai_capacity" {
  type    = number
  default = 1
}
variable "openai_api_version" {
  description = "Azure OpenAI API version used by the application"
  type        = string
  default     = "2025-04-01-preview"
}