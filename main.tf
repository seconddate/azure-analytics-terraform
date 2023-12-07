variable "env" {
  type        = string
  default     = "test"
  description = "Environment"
}

locals {
  customer_name = "dataai"
  common_tags = {
    Environment = var.env
    Owner = "Data&AI"
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

resource "random_string" "random" {
  length  = 6
  special = false
  upper   = false
}

# 리소스 그룹 생성
resource "azurerm_resource_group" "main_rg" {
  location = var.resource_group_location
  name     = "${var.resource_group_prefix}-${var.env}-${local.customer_name}"
  tags = local.common_tags
}

# Log Analytics 워크스페이스
resource "azurerm_log_analytics_workspace" "main_alaw" {
  name                = "law-${var.env}-${local.customer_name}"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.main_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags = local.common_tags
}

# Vnet 구성
resource "azurerm_virtual_network" "main_vnet" {
  name                = "vnet-${var.env}-${local.customer_name}"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.main_rg.name
  tags = local.common_tags
}

# subnet 구성
resource "azurerm_subnet" "main_subnet" {
  name                 = "subnet-${var.env}-${local.customer_name}"
  resource_group_name  = azurerm_resource_group.main_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# nsg 구성
resource "azurerm_network_security_group" "main_nsg" {
  name                = "nsg-${var.env}-${local.customer_name}"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.main_rg.name
  tags = local.common_tags
}


resource "azurerm_subnet_network_security_group_association" "main_nsg_association" {
  subnet_id                 = azurerm_subnet.main_subnet.id
  network_security_group_id = azurerm_network_security_group.main_nsg.id
}

# SSH role 구성
resource "azurerm_network_security_rule" "nsg_rule" {
  name                        = "SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main_rg.name
  network_security_group_name = azurerm_network_security_group.main_nsg.name
}

resource "azurerm_network_security_rule" "http_rule" {
  name                        = "HTTP"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main_rg.name
  network_security_group_name = azurerm_network_security_group.main_nsg.name
}

# Storage Account 생성
resource "azurerm_storage_account" "main_adls" {
  name                     = "adls${var.env}${local.customer_name}"
  resource_group_name      = azurerm_resource_group.main_rg.name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags = local.common_tags
}

# Event Hubs Namespace 생성
resource "azurerm_eventhub_namespace" "main_eventhub_namespace" {
  name                = "evhub-${var.env}-${local.customer_name}"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.main_rg.name
  sku                 = "Standard"
  tags = local.common_tags
}

# Event Hub 생성
resource "azurerm_eventhub" "main_eventhub" {
  name                = "${azurerm_eventhub_namespace.main_eventhub_namespace.name}"
  namespace_name      = azurerm_eventhub_namespace.main_eventhub_namespace.name
  resource_group_name = azurerm_resource_group.main_rg.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_stream_analytics_job" "main_steram_analytics_job" {
  name                                     = "saj-${var.env}-${local.customer_name}"
  resource_group_name                      = azurerm_resource_group.main_rg.name
  location                                 = var.resource_group_location
  compatibility_level                      = "1.2"
  data_locale                              = "ko-KR"
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  events_out_of_order_max_delay_in_seconds = 5
  streaming_units                          = 3

  transformation_query = "SELECT * INTO Output FROM Input"
  tags = local.common_tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "main_adls_filesystem" {
  name               = "datalake"
  storage_account_id = azurerm_storage_account.main_adls.id
}

resource "azurerm_synapse_workspace" "main_synapse_workspace" {
  name                                 = "synapse-${var.env}-${local.customer_name}"
  resource_group_name                  = azurerm_resource_group.main_rg.name
  location                             = var.resource_group_location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.main_adls_filesystem.id
  sql_administrator_login              = "sqladminuser"
  sql_administrator_login_password     = "aprkwhs1234!"

  aad_admin {
    login     = "AzureAD Admin"
    object_id = "fee2d061-a98d-4b6f-a08d-a67130755ea8"
    tenant_id = "97f42f55-f1db-4804-b1eb-08db083efd4f"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}
