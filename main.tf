module "private" {
  source = "./modules/private"
  
  # 모듈에 필요한 변수 전달
  tenant_id        = var.tenant_id
  subscription_id  = var.subscription_id
  client_id        = var.client_id
  client_secret    = var.client_secret
  object_id        = var.object_id
  env              = var.env
  resource_region = var.resource_region
  resource_region_aka = var.resource_region_aka
  customer_name = var.customer_name
  project_name            = var.project_name
  common_tags = local.common_tags
  vnet_group = var.private
}

module "public" {
  source = "./modules/public"
  
  # 모듈에 필요한 변수 전달
  tenant_id        = var.tenant_id
  subscription_id  = var.subscription_id
  client_id        = var.client_id
  client_secret    = var.client_secret
  object_id        = var.object_id
  env              = var.env
  resource_region = var.resource_region
  resource_region_aka = var.resource_region_aka
  customer_name = var.customer_name
  project_name            = var.project_name
  common_tags = local.common_tags
  vnet_group = var.public

  spoke_rg       = module.private.spoke_rg
  spoke_vnet   = module.private.spoke_vnet
  spoke_adls = module.private.spoke_adls
  spoke_eventhub_namespace = module.private.spoke_eventhub_namespace

  depends_on = [module.private]
}
