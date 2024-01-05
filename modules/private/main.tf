
# Private 리소스 그룹 생성
resource "azurerm_resource_group" "spoke_rg" {
  location = var.resource_region
  name     = "rg-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  tags = var.common_tags
}

# Vnet 구성
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "vnet-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_region
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags = var.common_tags
}

# Private DNS Zone for Event Hubs
resource "azurerm_private_dns_zone" "spoke_private_dns_zone" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = azurerm_resource_group.spoke_rg.name

  tags = var.common_tags
}

# Private Endpoint for Event Hubs Namespace
resource "azurerm_private_endpoint" "eventhub_private_endpoint" {
  name                = "pe-evhub-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  location            = var.resource_region
  resource_group_name = azurerm_resource_group.spoke_rg.name
  subnet_id           = azurerm_subnet.spoke_subnet.id

  private_service_connection {
    name                           = "psc-eventhub"
    private_connection_resource_id = azurerm_eventhub_namespace.spoke_eventhub_namespace.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.spoke_private_dns_zone.id]
  }
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "eventhub" {
  name                  = "pdz-link-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01-eventhub"
  resource_group_name   = azurerm_resource_group.spoke_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.spoke_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
}

# Event Hub Namespace Authorization Rule
resource "azurerm_eventhub_namespace_authorization_rule" "spoke_eventhub_namespace_auth_rule" {
  name                = "authorization-rule"
  namespace_name      = azurerm_eventhub_namespace.spoke_eventhub_namespace.name
  resource_group_name = azurerm_resource_group.spoke_rg.name

  listen = true
  send   = true
  manage = false
}

# subnet 구성
resource "azurerm_subnet" "spoke_subnet" {
  name                 = "subnet-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  resource_group_name  = azurerm_resource_group.spoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# nsg 구성
resource "azurerm_network_security_group" "spoke_nsg" {
  name                = "nsg-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  location            = var.resource_region
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags = var.common_tags
}


resource "azurerm_subnet_network_security_group_association" "spoke_nsg_association" {
  subnet_id                 = azurerm_subnet.spoke_subnet.id
  network_security_group_id = azurerm_network_security_group.spoke_nsg.id
}

# Private DNS Zone for Storage Account
resource "azurerm_private_dns_zone" "storage_private_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags                = var.common_tags
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage_private_endpoint" {
  name                = "pe-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01-storage"
  location            = var.resource_region
  resource_group_name = azurerm_resource_group.spoke_rg.name
  subnet_id           = azurerm_subnet.spoke_subnet.id

  private_service_connection {
    name                           = "psc-storage"
    private_connection_resource_id = azurerm_storage_account.spoke_adls.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01-storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_private_dns_zone.id]
  }
}

# Azure Data Lake Storage Gen2에 대한 Private Endpoint (Synapse Workspace의 데이터 저장소로 사용될 경우)
resource "azurerm_private_endpoint" "datalake_private_endpoint" {
  name                = "pe-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01-datalake"
  location            = var.resource_region
  resource_group_name = azurerm_resource_group.spoke_rg.name
  subnet_id           = azurerm_subnet.spoke_subnet.id

  private_service_connection {
    name                           = "psc-datalake"
    private_connection_resource_id = azurerm_storage_account.spoke_adls.id
    is_manual_connection           = false
    subresource_names              = ["dfs"]
  }

  private_dns_zone_group {
    name                 = "${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01-datalake-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_private_dns_zone.id]
  }
}

# Storage Account 생성
resource "azurerm_storage_account" "spoke_adls" {
  name                     = "adls${var.project_name}${var.resource_region_aka}${var.env}"
  resource_group_name      = azurerm_resource_group.spoke_rg.name
  location                 = var.resource_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags = var.common_tags
}

# Event Hubs Namespace 생성
resource "azurerm_eventhub_namespace" "spoke_eventhub_namespace" {
  name                = "evhub-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  location            = var.resource_region
  resource_group_name = azurerm_resource_group.spoke_rg.name
  sku                 = "Standard"
  tags = var.common_tags
}

# Event Hub 생성
resource "azurerm_eventhub" "spoke_eventhub" {
  name                = "${azurerm_eventhub_namespace.spoke_eventhub_namespace.name}"
  namespace_name      = azurerm_eventhub_namespace.spoke_eventhub_namespace.name
  resource_group_name = azurerm_resource_group.spoke_rg.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_stream_analytics_job" "spoke_steram_analytics_job" {
  name                                     = "saj-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  resource_group_name                      = azurerm_resource_group.spoke_rg.name
  location                                 = var.resource_region
  compatibility_level                      = "1.2"
  data_locale                              = "ko-KR"
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  events_out_of_order_max_delay_in_seconds = 5
  streaming_units                          = 3

  transformation_query = "SELECT * INTO Output FROM Input"
  tags = var.common_tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "spoke_adls_filesystem" {
  name               = "datalake"
  storage_account_id = azurerm_storage_account.spoke_adls.id
}

resource "azurerm_synapse_workspace" "spoke_synapse_workspace" {
  name                                 = "synapse-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  resource_group_name                  = azurerm_resource_group.spoke_rg.name
  location                             = var.resource_region
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.spoke_adls_filesystem.id
  sql_administrator_login              = "sqladminuser"
  sql_administrator_login_password     = "aprkwhs1234!"

  aad_admin {
    login     = "AzureAD Admin"
    object_id = var.object_id
    tenant_id = var.tenant_id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}