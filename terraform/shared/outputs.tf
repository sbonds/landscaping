output "resource_group_name" {
  value = azurerm_resource_group.resource_group.name
}

output "dns_zone_name" {
  value = azurerm_dns_zone.dns_zone.name
}
