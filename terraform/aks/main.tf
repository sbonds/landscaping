# Back-end
# terraform {
#   backend "azurerm" {
#     key                  = "core.terraform.tfstate"
#   }
# }

# Provider
provider "azurerm" { 
  version = "~> 1.40.0"
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Remote State Data
data "terraform_remote_state" "remote_state_core" {
  backend = "azurerm"
  config = {
    key                   = "core.terraform.tfstate"
    container_name        = var.prefix
    storage_account_name  = var.storage_account_name
    access_key            = var.storage_account_key
  }
}

# Resources
resource "azurerm_resource_group" "resource_group" {
  name                = "${var.workload}-${var.prefix}-aks"
  location            = var.region
  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "random_string" "random_string_aks_suffix" {
  length              = 5
  special             = false
  upper               = false
}

resource "azurerm_kubernetes_cluster" "kubernetescluster" {
  name                = "${var.prefix}-${var.workload}-aks-${random_string.random_string_aks_suffix.result}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = "${var.prefix}${var.workload}${random_string.random_string_aks_suffix.result}"

  default_node_pool {
    name                = "default"
    node_count          = var.aks_count
    enable_auto_scaling = var.aks_autoscale
    min_count           = var.aks_count_min
    max_count           = var.aks_count_max
    vm_size             = var.aks_sku
    os_disk_size_gb     = var.aks_os_disk
    type                = "VirtualMachineScaleSets"
    availability_zones  = [ "1", "2", "3"]
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = data.terraform_remote_state.remote_state_core.outputs.log_analytics_workspace_id
    }
    kube_dashboard {
      enabled = false
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard" # Required for availability zones
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload,
    Created = timestamp()
  }
}

resource "azurerm_devspace_controller" "devspacecontroller" {
  name                = "${var.prefix}-${var.workload}-aksdsc-${random_string.random_string_aks_suffix.result}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  sku {
    name = "S1"
    tier = "Standard"
  }
  
  target_container_host_resource_id        = "${azurerm_kubernetes_cluster.kubernetescluster.id}"
  target_container_host_credentials_base64 = "${base64encode(azurerm_kubernetes_cluster.kubernetescluster.kube_config_raw)}"

  tags = {
    Environment = var.prefix,
    Workload = var.workload,
  }
}

# All
locals {
  
}