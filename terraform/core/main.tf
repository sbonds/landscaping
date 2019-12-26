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

# Resources
resource "azurerm_resource_group" "resource_group" {
  name                = "${var.prefix}-${var.workload}-core"
  location            = var.region

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "random_string" "random_string_log_analytics_workspace_name_suffix" {
  length              = 4
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

resource "azurerm_dns_zone" "dns_zone" {
  name                = var.domain
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_dns_cname_record" "dns_cname_record" {
  name                = var.subdomain
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.resource_group.name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile.fqdn
}

resource "azurerm_dns_cname_record" "dns_cname_wildcard_record" {
  name                = "*.${var.subdomain}"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.resource_group.name
  ttl                 = 0
  record              = azurerm_traffic_manager_profile.traffic_manager_profile.fqdn
}

# All
locals {
  
}