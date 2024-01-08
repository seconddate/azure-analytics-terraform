variable "tenant_id" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "object_id" {}

variable "public" {
  type        = string
  default     = "hub"
  description = "Public Vnet Group Name"
}

variable "private" {
  type        = string
  default     = "spoke"
  description = "Private Vnet Group Name"
}

variable "env" {
  type        = string
  default     = "dev"
  description = "Environment"
}

variable "customer_name" {
  type        = string
  default     = "ioisoft"
  description = "Customer Name"
}

variable "resource_region" {
  type        = string
  default     = "koreacentral"
  description = "Resource Region"
}

variable "resource_region_aka" {
  type        = string
  default     = "kc"
  description = "Resource Region Abbreviation"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "mauritius"
}

locals {
  seoul_tz  = timeadd(timestamp(), "9h")
  common_tags = {
    Environment = var.env
    Owner = var.customer_name
    Project = var.project_name
    ManagedBy = "Terraform"
    DeploymentTimestamp = formatdate("YYYY-MM-DD HH:MM", local.seoul_tz)
  }
}