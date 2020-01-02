# Back-end
terraform {
  backend "azurerm" {
    key                  = "shared.terraform.tfstate"
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
  name                = "${var.workload}-${var.prefix}-core"
  location            = var.region

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_container_registry" "acr" {
  name                     = "${var.workload}registry"
  location                 = var.region
  resource_group_name      = azurerm_resource_group.resource_group.name
  sku                      = "Basic"
  
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

resource "azurerm_dns_zone" "dns_zone" {
  name                = var.domain
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

# All
locals {
  
}