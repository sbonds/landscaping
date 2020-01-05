# Back-end
terraform {
  backend "azurerm" {
    key                  = "core.terraform.tfstate"
  }
}

# Provider
provider "azurerm" { 
  version = "=1.38.0"
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

resource "azurerm_traffic_manager_profile" "traffic_manager_profile" {
  name                = "${var.prefix}-traffic-manager-profile"
  resource_group_name = azurerm_resource_group.resource_group.name

  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${replace(var.subdomain, ".", "-")}-${replace(var.domain, ".", "-")}"
    ttl           = 1
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/health"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_dns_cname_record" "dns_cname_record" {
  name                = var.subdomain
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile.fqdn
}

resource "azurerm_dns_cname_record" "dns_cname_wildcard_record" {
  name                = "*.${var.subdomain}"
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile.fqdn
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
  ]

  depends_on = [azurerm_key_vault.keyvault]
}

resource "azurerm_key_vault_secret" "keyvaultsecretsapk" {
  name         = "APPINSIGHTSINSTRUMENTATIONKEY"
  value        = azurerm_application_insights.appinsights.instrumentation_key
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [azurerm_key_vault_access_policy.keyvaultpolicysp]
}

# All
locals {
  
}