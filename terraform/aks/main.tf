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
  name                = "${var.prefix}-${var.workload}-aks"
  location            = var.region
}

resource "random_string" "random_string_aks_suffix" {
  length              = 4
  special             = false
  upper               = false
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "${var.prefix}-${var.workload}-aks-${random_string_aks_suffix}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = "${var.prefix}${var.workload}${random_string_aks_suffix}"

  default_node_pool {
    name       = "default"
    node_count = var.aks_count
    vm_size    = var.aks_sku
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload,
    Deployment = "Blue"
  }
}

# All
locals {
  
}