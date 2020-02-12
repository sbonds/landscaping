output "resource_group_name" {
  value = azurerm_resource_group.resource_group.name
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.log_analytics_workspace.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.log_analytics_workspace.id
}

output "traffic_manager_profile_name_be" {
  value = azurerm_traffic_manager_profile.traffic_manager_profile_be.name
}

output "traffic_manager_profile_id_be" {
  value = azurerm_traffic_manager_profile.traffic_manager_profile_be.id
}

output "traffic_manager_profile_name_fe" {
  value = azurerm_traffic_manager_profile.traffic_manager_profile_fe.name
}

output "traffic_manager_profile_id_fe" {
  value = azurerm_traffic_manager_profile.traffic_manager_profile_fe.id
}

output "appinsights_instrumentation_key" {
  value = azurerm_application_insights.appinsights.instrumentation_key
}

output "cosmosdbCollectionName" {
  value = azurerm_cosmosdb_mongo_collection.db.name
}

output "cosmosdbDatabaseName" {
  value = azurerm_cosmosdb_account.db.name
}

output "cosmosdbHostName" {
  value = azurerm_cosmosdb_account.db.endpoint
}

output "cosmosdbMongodbConnectionString" {
  value = azurerm_cosmosdb_account.db.connection_strings[0]
}

output "cosmosdbPassword" {
  value = azurerm_cosmosdb_account.db.primary_master_key
}