# Private 리소스 그룹 생성
resource "azurerm_resource_group" "hub_rg" {
  location = var.resource_region
  name     = "rg-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  tags     = var.common_tags
}

resource "azurerm_virtual_network" "hub_vnet" {
  name                = "vnet-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  address_space       = ["10.1.0.0/16"]
  location            = var.resource_region
  resource_group_name = azurerm_resource_group.hub_rg.name
  tags                = var.common_tags
}

resource "azurerm_subnet" "hub_subnet" {
  name                 = "subnet-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
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
  name                = "nsg-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  location            = var.resource_region
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
  name                = "appinsights-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  application_type    = "web"
}

# App Service Plan
resource "azurerm_service_plan" "linux_service_plan" {
  name                = "asp-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  os_type             = "Linux"
  sku_name            = "S1"
}

# Function App
resource "azurerm_linux_function_app" "hub_function_linux" {
  name                = "func-linux-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  service_plan_id  = azurerm_service_plan.linux_service_plan.id

  storage_account_name= var.spoke_adls.name
  storage_account_access_key = var.spoke_adls.primary_access_key
  tags = var.common_tags

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
    EVENTHUB_NAME="evhub-${var.project_name}-${var.vnet_group}-${var.resource_region_aka}-${var.env}-01"
    "EVENT_HUB_CONNECTION" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.eventhub_secret.id})"
    "WEBSITE_VNET_ROUTE_ALL"            = "1"
    "WEBSITE_VNET_PREMIUM"              = "1"
    "WEBSITE_VNET_NAME"                 = azurerm_virtual_network.hub_vnet.name
    "WEBSITE_VNET_RESOURCE_GROUP"       = azurerm_resource_group.hub_rg.name
  }

  identity {
    type = "SystemAssigned"
  }
}

# Vnet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "hub_asp_connection" {
  app_service_id = azurerm_linux_function_app.hub_function_linux.id
  subnet_id      = azurerm_subnet.hub_subnet.id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke_peering" {
  name                      = "hub-to-spoke-peering"
  resource_group_name       = azurerm_resource_group.hub_rg.name
  virtual_network_name      = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = var.spoke_vnet.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub_peering" {
  name                      = "spoke-to-hub-peering"
  resource_group_name       = var.spoke_rg.name
  virtual_network_name      = var.spoke_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id
}

# Key Vault 생성
resource "azurerm_key_vault" "hub_key_vault" {
  name                        = "kv${var.project_name}${var.resource_region_aka}${var.env}01"
  location                    = var.resource_region
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

  tags = var.common_tags
}

# Event Hub 연결 문자열을 Key Vault에 저장
resource "azurerm_key_vault_secret" "eventhub_secret" {
  name         = "eventhub-namespace-private-dns"
  value        = var.spoke_eventhub_namespace.default_primary_connection_string
  key_vault_id = azurerm_key_vault.hub_key_vault.id
}

resource "azurerm_key_vault_access_policy" "key_vault_access_policy" {
  key_vault_id = azurerm_key_vault.hub_key_vault.id

  tenant_id = var.tenant_id
  object_id = azurerm_linux_function_app.hub_function_linux.identity[0].principal_id

  secret_permissions = [
    "Get",
  ]
}