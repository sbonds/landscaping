/* resource "azurerm_resource_group" "storage" {
  name     = "${var.prefix_environment}-${var.prefix_workload}-${var.storage_identifier}"
  location = var.region_primary
}

resource "azurerm_storage_account" "storage" {
  name                     = "${var.prefix_workload}${var.prefix_environment}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = var.storage_tier
  account_replication_type = var.storage_resiliency
}

*/