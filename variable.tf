variable "tenant_id" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}

variable "env" {
  type        = string
  default     = "dev"
  description = "Environment"
}

locals {
  public = "hub"
  private = "spoke"
  customer_name = "pnpeople"
  common_tags = {
    Environment = var.env
    Owner = "P&PEOPLE"
    ManagedBy = "Terraform"
    DeploymentTimestamp = timeadd(timestamp(), "9h")
  }
}

variable "resource_group_location" {
  type        = string
  default     = "koreacentral"
  description = "Location of the resource group."
}

variable "resource_group_prefix" {
  description = "Prefix for the resource group name."
  type        = string
  default     = "rg"
}