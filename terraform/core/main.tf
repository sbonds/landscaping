# Back-end
terraform {
  backend "azurerm" {
    key                  = "core.terraform.tfstate"
  }
}

# Provider
provider "azurerm" { 
  version = "~> 1.40.0"
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

data "azurerm_client_config" "current" {}

# Remote State Data
data "terraform_remote_state" "remote_state_shared" {
  backend = "azurerm"
  config = {
    key                   = "shared.terraform.tfstate"
    container_name        = "shared"
    storage_account_name  = var.storage_account_name
    access_key            = var.storage_account_key
  }
}

# Resources
resource "azurerm_resource_group" "resource_group" {
  name                = "${var.workload}-${var.prefix}-core"
  location            = var.region

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "random_string" "random_string_log_analytics_workspace_name_suffix" {
  length              = 5
  special             = false
  upper               = false
}

resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "${var.prefix}-log-analytics-workspace-${random_string.random_string_log_analytics_workspace_name_suffix.result}"
  location            = var.region
  resource_group_name = azurerm_resource_group.resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_traffic_manager_profile" "traffic_manager_profile_fe" {
  name                = "${var.prefix}-fe-traffic-manager-profile"
  resource_group_name = azurerm_resource_group.resource_group.name

  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "www-${replace(var.subdomain, ".", "-")}-${replace(var.domain, ".", "-")}"
    ttl           = 1
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/index.html"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload,
    Component = "www"
  }
}

resource "azurerm_dns_cname_record" "dns_cname_record_fe" {
  name                = "fe.${var.subdomain}"
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile_fe.fqdn
}

resource "azurerm_dns_cname_record" "dns_cname_wildcard_record_fe" {
  name                = "*.fe.${var.subdomain}"
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile_fe.fqdn
}

resource "azurerm_traffic_manager_profile" "traffic_manager_profile_be" {
  name                = "${var.prefix}-be-traffic-manager-profile"
  resource_group_name = azurerm_resource_group.resource_group.name

  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "api-${replace(var.subdomain, ".", "-")}-${replace(var.domain, ".", "-")}"
    ttl           = 1
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/api/getRegions"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload,
    Component = "api"
  }
}

resource "azurerm_dns_cname_record" "dns_cname_record_be" {
  name                = "be.${var.subdomain}"
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile_be.fqdn
}

resource "azurerm_dns_cname_record" "dns_cname_wildcard_record_be" {
  name                = "*.be.${var.subdomain}"
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile_be.fqdn
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.workload}${var.prefix}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  application_type    = "Web"

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_cosmosdb_account" "db" {
  name                = "${var.workload}${var.prefix}db"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_automatic_failover = true

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  geo_location {
    location          = azurerm_resource_group.resource_group.location
    failover_priority = 0
  }

}

resource "azurerm_cosmosdb_mongo_database" "db" {
  name                = "${var.workload}${var.prefix}db"
  account_name        = azurerm_cosmosdb_account.db.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_cosmosdb_mongo_collection" "db" {
  name                = "${var.workload}${var.prefix}db"
  resource_group_name = azurerm_resource_group.resource_group.name
  account_name        = azurerm_cosmosdb_account.db.name
  database_name       = azurerm_cosmosdb_mongo_database.db.name

  default_ttl_seconds = "604800"
  shard_key           = "_id"
  throughput          = 400

  indexes {
    key    = "_id"
    unique = true
  }
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "${var.workload}${var.prefix}"
  location                    = azurerm_resource_group.resource_group.location
  resource_group_name         = azurerm_resource_group.resource_group.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id

  sku {
    name = "standard"
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_key_vault_access_policy" "keyvaultpolicysp" {
  vault_name          = azurerm_key_vault.keyvault.name
  resource_group_name = azurerm_key_vault.keyvault.resource_group_name

  tenant_id = "${data.azurerm_client_config.current.tenant_id}"
  object_id = "${data.azurerm_client_config.current.service_principal_object_id}"

  secret_permissions = [
    "get", 
    "set", 
    "list",
    "delete",
  ]

  depends_on = [azurerm_key_vault.keyvault]
}

resource "azurerm_key_vault_secret" "APPINSIGHTSINSTRUMENTATIONKEY" {
  name         = "APPINSIGHTSINSTRUMENTATIONKEY"
  value        = azurerm_application_insights.appinsights.instrumentation_key
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "APIHOSTNAME" {
  name         = "APIHOSTNAME"
  value        = "api-${replace(var.subdomain, ".", "-")}-${replace(var.domain, ".", "-")}.trafficmanager.net"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "WWWHOSTNAME" {
  name         = "WWWHOSTNAME"
  value        = "www-${replace(var.subdomain, ".", "-")}-${replace(var.domain, ".", "-")}.trafficmanager.net"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "APIHOSTNAMEEXT" {
  name         = "APIHOSTNAMEEXT"
  value        = "be.${var.subdomain}.${var.domain}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "WWWHOSTNAMEEXT" {
  name         = "WWWHOSTNAMEEXT"
  value        = "fe.${var.subdomain}.${var.domain}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "APIHOSTNAMEROOT" {
  name         = "APIHOSTNAMEROOT"
  value        = "api.${var.domain}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "WWWHOSTNAMEROOT" {
  name         = "WWWHOSTNAMEROOT"
  value        = "www.${var.domain}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "APEXHOSTNAMEROOT" {
  name         = "APEXHOSTNAMEROOT"
  value        = "${var.domain}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "DOCSHOSTNAME" {
  name         = "DOCSHOSTNAME"
  value        = "docs-${replace(var.subdomain, ".", "-")}-${replace(var.domain, ".", "-")}.trafficmanager.net"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "DOCSHOSTNAMEEXT" {
  name         = "DOCSHOSTNAMEEXT"
  value        = "docs.${var.subdomain}.${var.domain}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "DOCSHOSTNAMEROOT" {
  name         = "DOCSHOSTNAMEROOT"
  value        = "docs.${var.domain}"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "cosmosdbCollectionName" {
  name         = "cosmosdbCollectionName"
  value        = azurerm_cosmosdb_mongo_collection.db.name
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "cosmosdbDatabaseName" {
  name         = "cosmosdbDatabaseName"
  value        = azurerm_cosmosdb_account.db.name
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "cosmosdbHostName" {
  name         = "cosmosdbHostName"
  value        = azurerm_cosmosdb_account.db.endpoint
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "cosmosdbMongodbConnectionString" {
  name         = "cosmosdbMongodbConnectionString"
  value        = azurerm_cosmosdb_account.db.connection_strings[0]
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

resource "azurerm_key_vault_secret" "cosmosdbPassword" {
  name         = "cosmosdbPassword"
  value        = azurerm_cosmosdb_account.db.primary_master_key
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

# All
locals {
  
}