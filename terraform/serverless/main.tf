# Back-end
terraform {
  backend "azurerm" {
    key                  = "serverless.terraform.tfstate"
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
  name                = "${var.workload}-${var.prefix}-serverless"
  location            = var.region
  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

## AppService - frontend
resource "azurerm_app_service_plan" "appservice" {
  name                     = "${var.workload}-${var.prefix}-webapp-fe"
  resource_group_name      = "${azurerm_resource_group.resource_group.name}"
  location                 = "${azurerm_resource_group.resource_group.location}"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "appservice" {
  name                     = "${var.workload}-${var.prefix}-webapp-fe"
  resource_group_name      = "${azurerm_resource_group.resource_group.name}"
  location                 = "${azurerm_resource_group.resource_group.location}"
  app_service_plan_id      = "${azurerm_app_service_plan.appservice.id}"

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${data.terraform_remote_state.remote_state_core.outputs.appinsights_instrumentation_key}"
  }

}

resource "azurerm_dns_cname_record" "dns_cname_awverify_domain_fe" {
  name                = "awverify.${var.prefixdomain}"
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_app_service.appservice.default_site_hostname
}

resource "azurerm_dns_cname_record" "dns_cname_awverify_azure_fe" {
  name                = "awverify.fe.${var.prefix}"
  zone_name           = data.terraform_remote_state.remote_state_shared.outputs.dns_zone_name
  resource_group_name = data.terraform_remote_state.remote_state_shared.outputs.resource_group_name
  ttl                 = 0
  record              = azurerm_app_service.appservice.default_site_hostname
}

resource "azurerm_app_service_custom_hostname_binding" "WWWHOSTNAME" {
  hostname            = "${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAME}"
  app_service_name    = azurerm_app_service.appservice.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_app_service_custom_hostname_binding" "WWWHOSTNAMEEXT" {
  hostname            = "${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAMEEXT}"
  app_service_name    = azurerm_app_service.appservice.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_app_service_custom_hostname_binding" "WWWHOSTNAMEROOT" {
  hostname            = "${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAMEROOT}"
  app_service_name    = azurerm_app_service.appservice.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_traffic_manager_endpoint" "webappfe" {
  name                = "${var.workload}-${var.prefix}-webapp-fe"
  resource_group_name = "${data.terraform_remote_state.remote_state_core.outputs.resource_group_name}"
  profile_name        = "${data.terraform_remote_state.remote_state_core.outputs.traffic_manager_profile_name_fe}"
  target_resource_id  = azurerm_app_service.appservice.id
  type                = "azureEndpoints"
  weight              = 100
}

## FunctionApp - backend
resource "azurerm_storage_account" "functionapp" {
  name                     = "${var.workload}${var.prefix}funcbe"
  resource_group_name      = "${azurerm_resource_group.resource_group.name}"
  location                 = "${azurerm_resource_group.resource_group.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_app_service_plan" "functionapp" {
  name                = "${var.workload}-${var.prefix}-func-be"
  location            = "${azurerm_resource_group.resource_group.location}"
  resource_group_name = "${azurerm_resource_group.resource_group.name}"
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_function_app" "functionapp" {
  name                      = "${var.workload}-${var.prefix}-func-be"
  location                  = "${azurerm_resource_group.resource_group.location}"
  resource_group_name       = "${azurerm_resource_group.resource_group.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.functionapp.id}"
  storage_connection_string = "${azurerm_storage_account.functionapp.primary_connection_string}"
  version                   = "~2"

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${data.terraform_remote_state.remote_state_core.outputs.appinsights_instrumentation_key}",
    "cosmosdbCollectionName" = "${data.terraform_remote_state.remote_state_core.outputs.cosmosdbCollectionName}",
    "cosmosdbDatabaseName" = "${data.terraform_remote_state.remote_state_core.outputs.cosmosdbDatabaseName}",
    "cosmosdbHostName" = "${data.terraform_remote_state.remote_state_core.outputs.cosmosdbHostName}",
    "cosmosdbMongodbConnectionString" ="${data.terraform_remote_state.remote_state_core.outputs.cosmosdbMongodbConnectionString}",
    "cosmosdbPassword" = "${data.terraform_remote_state.remote_state_core.outputs.cosmosdbPassword}"
  }

  site_config {
    cors {
      allowed_origins = [
        "http://${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAME}",
        "http://${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAMEEXT}",
        "http://${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAMEROOT}",
        "https://${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAME}",
        "https://${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAMEEXT}",
        "https://${data.terraform_remote_state.remote_state_core.outputs.WWWHOSTNAMEROOT}",
      ]
      support_credentials = true
    }
  }

  tags = {
    Environment = var.prefix,
    Workload = var.workload
  }
}

resource "azurerm_app_service_custom_hostname_binding" "APIHOSTNAME" {
  hostname            = "${data.terraform_remote_state.remote_state_core.outputs.APIHOSTNAME}"
  app_service_name    = azurerm_function_app.functionapp.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_app_service_custom_hostname_binding" "APIHOSTNAMEEXT" {
  hostname            = "${data.terraform_remote_state.remote_state_core.outputs.APIHOSTNAMEEXT}"
  app_service_name    = azurerm_function_app.functionapp.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_traffic_manager_endpoint" "funcbe" {
  name                = "${var.workload}-${var.prefix}-func-be"
  resource_group_name = "${data.terraform_remote_state.remote_state_core.outputs.resource_group_name}"
  profile_name        = "${data.terraform_remote_state.remote_state_core.outputs.traffic_manager_profile_name_be}"
  target_resource_id  = azurerm_function_app.functionapp.id
  type                = "azureEndpoints"
  weight              = 100
}

# All
locals {
  
}