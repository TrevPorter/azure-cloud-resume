output "resource_group" {
  description = "Resource group name"
  value       = data.azurerm_resource_group.this.name
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.this.name
}

output "static_website_url" {
  description = "Azure Storage static website endpoint"
  value       = azurerm_storage_account.this.primary_web_endpoint
}

output "frontdoor_url" {
  description = "Azure Front Door endpoint URL"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.this.host_name}"
}

output "frontdoor_endpoint" {
  value = azurerm_cdn_frontdoor_endpoint.this.host_name
}

output "function_hostname" {
  value = azurerm_linux_function_app.this.default_hostname
}

output "static_site_url" {
  value = azurerm_storage_account.this.primary_web_endpoint
}


