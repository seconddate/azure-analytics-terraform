resource "random_string" "random" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------ Public Start
# Public 리소스 그룹 생성
resource "azurerm_resource_group" "hub_rg" {
  location = var.resource_group_location
  name     = "${var.resource_group_prefix}-${local.public}-${var.env}-${local.customer_name}"
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "hub_vnet" {
  name                = "vnet-${local.public}-${var.env}-${local.customer_name}"
  address_space       = ["10.1.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.hub_rg.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "hub_subnet" {
  name                 = "subnet-${local.public}-${var.env}-${local.customer_name}"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.1.1.0/24"]

  delegation {
    name = "appServiceDelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "hub_nsg" {
  name                = "nsg-${local.public}-${var.env}-${local.customer_name}"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.hub_rg.name
}

resource "azurerm_network_security_rule" "allow_specific_ip" {
  name                        = "allow-specific-ip"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "125.131.104.40"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hub_rg.name
  network_security_group_name = azurerm_network_security_group.hub_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "hub_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.hub_subnet.id
  network_security_group_id = azurerm_network_security_group.hub_nsg.id
}

# Application Insights 리소스 생성
resource "azurerm_application_insights" "hub_app_insights" {
  name                = "appinsights-${var.env}-${local.customer_name}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  application_type    = "web"
}

# App Service Plan
resource "azurerm_service_plan" "linux_service_plan" {
  name                = "asp-${var.env}-${local.customer_name}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  os_type             = "Linux"
  sku_name            = "S1"
}

# Function App
resource "azurerm_linux_function_app" "hub_function_linux" {
  name                = "func-linux-${var.env}-${local.customer_name}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  service_plan_id  = azurerm_service_plan.linux_service_plan.id

  storage_account_name= azurerm_storage_account.spoke_adls.name
  storage_account_access_key = azurerm_storage_account.spoke_adls.primary_access_key
  tags = local.common_tags

   site_config {
    application_stack {
      python_version = "3.10"
    }
    # CORS 설정 추가
    cors {
      allowed_origins = [
        "https://portal.azure.com"
      ]
    }
  }
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.hub_app_insights.instrumentation_key
    SCM_DO_BUILD_DURING_DEPLOYMENT=true
    ENABLE_ORYX_BUILD=true
    "EVENT_HUB_CONNECTION" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.eventhub_secret.id})"
    "WEBSITE_VNET_ROUTE_ALL"            = "1"
    "WEBSITE_VNET_PREMIUM"              = "1"
    "WEBSITE_VNET_NAME"                 = azurerm_virtual_network.hub_vnet.name
    "WEBSITE_VNET_RESOURCE_GROUP"       = azurerm_resource_group.hub_rg.name
  }
}

# Vnet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "hub_asp_connection" {
  app_service_id = azurerm_linux_function_app.hub_function_linux.id
  subnet_id      = azurerm_subnet.hub_subnet.id
}

# ------------------------------ Public End

resource "azurerm_virtual_network_peering" "hub_to_spoke_peering" {
  name                      = "hub-to-spoke-peering"
  resource_group_name       = azurerm_virtual_network.hub_vnet.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnet.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub_peering" {
  name                      = "spoke-to-hub-peering"
  resource_group_name       = azurerm_virtual_network.spoke_vnet.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id
}

# ------------------------------ Private Start
# Private 리소스 그룹 생성
resource "azurerm_resource_group" "spoke_rg" {
  location = var.resource_group_location
  name     = "${var.resource_group_prefix}-${local.private}-${var.env}-${local.customer_name}"
  tags = local.common_tags
}

# Vnet 구성
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "vnet-${local.private}-${var.env}-${local.customer_name}"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags = local.common_tags
}

# Private DNS Zone for Event Hubs
resource "azurerm_private_dns_zone" "spoke_private_dns_zone" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = azurerm_resource_group.spoke_rg.name

  tags = local.common_tags
}

# Private Endpoint for Event Hubs Namespace
resource "azurerm_private_endpoint" "eventhub_private_endpoint" {
  name                = "pe-${var.env}-${local.customer_name}-eventhub"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  subnet_id           = azurerm_subnet.spoke_subnet.id

  private_service_connection {
    name                           = "psc-eventhub"
    private_connection_resource_id = azurerm_eventhub_namespace.spoke_eventhub_namespace.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "${var.env}-${local.customer_name}-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.spoke_private_dns_zone.id]
  }
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "eventhub" {
  name                  = "pdz-link-${var.env}-${local.customer_name}-eventhub"
  resource_group_name   = azurerm_resource_group.spoke_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.spoke_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
}

# Event Hub Namespace Authorization Rule
data "azurerm_eventhub_namespace_authorization_rule" "spoke_eventhub_namespace_auth_rule" {
  name                = "authorization-rule"
  namespace_name      = azurerm_eventhub_namespace.spoke_eventhub_namespace.name
  resource_group_name = azurerm_resource_group.spoke_rg.name
}

resource "azurerm_eventhub_namespace_authorization_rule" "example_auth_rule" {
  name                = "authorization-rule"
  namespace_name      = azurerm_eventhub_namespace.spoke_eventhub_namespace.name
  resource_group_name = azurerm_resource_group.spoke_rg.name

  listen = true
  send   = true
  manage = false
}

# subnet 구성
resource "azurerm_subnet" "spoke_subnet" {
  name                 = "subnet-${var.env}-${local.customer_name}"
  resource_group_name  = azurerm_resource_group.spoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# nsg 구성
resource "azurerm_network_security_group" "spoke_nsg" {
  name                = "nsg-${var.env}-${local.customer_name}"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags = local.common_tags
}


resource "azurerm_subnet_network_security_group_association" "spoke_nsg_association" {
  subnet_id                 = azurerm_subnet.spoke_subnet.id
  network_security_group_id = azurerm_network_security_group.spoke_nsg.id
}

# Private DNS Zone for Storage Account
resource "azurerm_private_dns_zone" "storage_private_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags                = local.common_tags
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage_private_endpoint" {
  name                = "pe-${var.env}-${local.customer_name}-storage"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  subnet_id           = azurerm_subnet.spoke_subnet.id

  private_service_connection {
    name                           = "psc-storage"
    private_connection_resource_id = azurerm_storage_account.spoke_adls.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "${var.env}-${local.customer_name}-storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_private_dns_zone.id]
  }
}

# Azure Data Lake Storage Gen2에 대한 Private Endpoint (Synapse Workspace의 데이터 저장소로 사용될 경우)
resource "azurerm_private_endpoint" "datalake_private_endpoint" {
  name                = "pe-${var.env}-${local.customer_name}-datalake"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  subnet_id           = azurerm_subnet.spoke_subnet.id

  private_service_connection {
    name                           = "psc-datalake"
    private_connection_resource_id = azurerm_storage_account.spoke_adls.id
    is_manual_connection           = false
    subresource_names              = ["dfs"]
  }

  private_dns_zone_group {
    name                 = "${var.env}-${local.customer_name}-datalake-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_private_dns_zone.id]
  }
}

# Storage Account 생성
resource "azurerm_storage_account" "spoke_adls" {
  name                     = "adls${local.private}${var.env}${local.customer_name}"
  resource_group_name      = azurerm_resource_group.spoke_rg.name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags = local.common_tags
}

# Event Hubs Namespace 생성
resource "azurerm_eventhub_namespace" "spoke_eventhub_namespace" {
  name                = "evhub-${var.env}-${local.customer_name}"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  sku                 = "Standard"
  tags = local.common_tags
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
  name                                     = "saj-${var.env}-${local.customer_name}"
  resource_group_name                      = azurerm_resource_group.spoke_rg.name
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

resource "azurerm_storage_data_lake_gen2_filesystem" "spoke_adls_filesystem" {
  name               = "datalake"
  storage_account_id = azurerm_storage_account.spoke_adls.id
}

resource "azurerm_synapse_workspace" "spoke_synapse_workspace" {
  name                                 = "synapse-${var.env}-${local.customer_name}"
  resource_group_name                  = azurerm_resource_group.spoke_rg.name
  location                             = var.resource_group_location
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

  tags = local.common_tags
}
# ------------------------------ Private End

# Key Vault 생성
resource "azurerm_key_vault" "hub_key_vault" {
  name                        = "kv-${var.env}-${local.customer_name}"
  location                    = var.resource_group_location
  resource_group_name         = azurerm_resource_group.hub_rg.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = var.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
      "Set"
    ]
  }

  tags = local.common_tags
}

# Event Hub 연결 문자열을 Key Vault에 저장
resource "azurerm_key_vault_secret" "eventhub_secret" {
  name         = "eventhub-namespace-dns"
  value        = azurerm_eventhub_namespace.spoke_eventhub_namespace.default_primary_connection_string
  key_vault_id = azurerm_key_vault.hub_key_vault.id
}