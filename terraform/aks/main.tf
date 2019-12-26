# Back-end
# terraform {
#   backend "azurerm" {
#     key                  = "core.terraform.tfstate"
#   }
# }

# Provider
provider "azurerm" { 
  version = "=1.38.0"
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Remote State Data
data "terraform_remote_state" "remote_state_core" {
  backend = "azurerm"
  config = {
    key               = "core.terraform.tfstate"
    container_name    = var.prefix
  }
}

# Resources
resource "azurerm_resource_group" "resource_group" {
  name                = "${var.prefix}-${var.workload}-aks"
  location            = var.region
  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "random_string" "random_string_aks_suffix" {
  length              = 4
  special             = false
  upper               = false
}

resource "azurerm_kubernetes_cluster" "kubernetescluster" {
  name                = "${var.prefix}-${var.workload}-aks-${random_string.random_string_aks_suffix.result}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = "${var.prefix}${var.workload}${random_string.random_string_aks_suffix.result}"

  default_node_pool {
    name       = "default"
    node_count = var.aks_count
    vm_size    = var.aks_sku
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  agent_pool_profile {
    name                = "default"
    count               = var.aks_count
    min_count           = var.aks_count_min
    max_count           = var.aks_count_max
    vm_size             = var.aks_sku
    os_type             = var.aks_os_type
    os_disk_size_gb     = var.aks_os_disk
    type                = "VirtualMachineScaleSets"
    availability_zones  = [ "1", "2", "3"]
    enable_auto_scaling = true
    #vnet_subnet_id      = var.vnet_subnet_id
  }

  #network_profile {
  #  network_plugin     = var.network_plugin
  #  network_policy     = var.network_policy
  #  load_balancer_sku  = var.load_balancer_sku
  #  service_cidr       = var.service_cidr
  #  dns_service_ip     = var.dns_service_ip
  #  docker_bridge_cidr = var.docker_bridge_cidr
  #}

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = data.terraform_remote_state.remote_state_core.outputs.log_analytics_workspace_id
    }
    kube_dashboard {
      enabled = false
    }
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload,
    Deployment = "Created"
  }
}

# All
locals {
  
}