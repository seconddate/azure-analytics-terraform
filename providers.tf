terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_keys_on_destroy = true
      recover_soft_deleted_keys          = true
    }
  }
  skip_provider_registration = true
  subscription_id 	= var.subscription_id
  client_id 		= var.client_id
  client_secret 	= var.client_secret
  tenant_id 		= var.tenant_id
}