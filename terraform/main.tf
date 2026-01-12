data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}


resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }

  allow_nested_items_to_be_public = true
}

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "fd-cloud-resume"
  resource_group_name = data.azurerm_resource_group.this.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "cloud-resume-${random_string.suffix.result}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}


resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "storage-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  load_balancing {
    successful_samples_required = 1
  }
}

resource "azurerm_cdn_frontdoor_origin" "this" {
  name                          = "storage-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id

  host_name                      = azurerm_storage_account.this.primary_web_host
  origin_host_header             = azurerm_storage_account.this.primary_web_host
  http_port                      = 80
  https_port                     = 443
  certificate_name_check_enabled = true
  enabled                        = true
}

resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.this.id]

  patterns_to_match   = ["/*"]
  supported_protocols = ["Https"]
  forwarding_protocol = "HttpsOnly"

  https_redirect_enabled = false

  cdn_frontdoor_custom_domain_ids = []
}



resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_cdn_frontdoor_custom_domain" "resume" {
  name                     = "resume-domain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  host_name                = "www.tporter.dev"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_service_plan" "flex" {
  name                = "asp-cloud-resume-flex"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  os_type  = "Linux"
  sku_name = "FC1" # REQUIRED for Flex Consumption
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = "func-cloud-resume"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  runtime_name    = "python"
  runtime_version = "3.11"

  service_plan_id = azurerm_service_plan.flex.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint = azurerm_storage_container.function_code.id
  storage_authentication_type = "SystemAssignedIdentity"

  identity {
    type = "SystemAssigned"
  }

  site_config {}  # required

  app_settings = {
    
    COSMOS_ENDPOINT          = azurerm_cosmosdb_account.this.endpoint
  }
}



resource "azurerm_cosmosdb_account" "this" {
  name                = "cosmos-cloud-resume"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name

  offer_type = "Standard"
  kind       = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  capabilities {
    name = "EnableServerless"
  }

  geo_location {
    location          = data.azurerm_resource_group.this.location
    failover_priority = 0
  }
}
resource "time_sleep" "wait_for_cosmos" {
  depends_on = [
    azurerm_cosmosdb_account.this
  ]

  create_duration = "60s"
}

resource "azurerm_cosmosdb_sql_database" "this" {
  name                = "resume"
  resource_group_name = data.azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name

  depends_on = [
    time_sleep.wait_for_cosmos
  ]
}


resource "azurerm_cosmosdb_sql_container" "visits" {
  name                = "visits"
  resource_group_name = data.azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name

  partition_key_paths = ["/id"]
  depends_on = [
  azurerm_cosmosdb_sql_database.this
 ]
}


resource "azurerm_cosmosdb_sql_container" "unique" {
  name                = "uniqueVisitors"
  resource_group_name = data.azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name

  partition_key_paths = ["/date"]
  default_ttl         = 2592000
  depends_on = [
  azurerm_cosmosdb_sql_database.this
 ]
}


data "azurerm_cosmosdb_sql_role_definition" "data_contributor" {
  resource_group_name = data.azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  role_definition_id  = "00000000-0000-0000-0000-000000000002"
}
resource "azurerm_cosmosdb_sql_role_assignment" "function" {
  resource_group_name = data.azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name

  role_definition_id = data.azurerm_cosmosdb_sql_role_definition.data_contributor.id
  principal_id       = azurerm_function_app_flex_consumption.this.identity[0].principal_id
  scope              = azurerm_cosmosdb_account.this.id
}
resource "azurerm_storage_container" "function_code" {
  name                  = "function-code"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_role_assignment" "function_storage_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_cdn_frontdoor_origin_group" "api" {
  name                     = "api-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  load_balancing {
    successful_samples_required = 1
  }
}

resource "azurerm_cdn_frontdoor_origin" "api" {
  name                          = "function-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.api.id

  host_name          = azurerm_function_app_flex_consumption.this.default_hostname
  origin_host_header = azurerm_function_app_flex_consumption.this.default_hostname


  https_port                     = 443
  http_port                      = 80
  certificate_name_check_enabled = true
  enabled                        = true
}

resource "azurerm_cdn_frontdoor_route" "api" {
  name                          = "api-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.api.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.api.id]

  patterns_to_match   = ["/api/*"]
  supported_protocols = ["Https"]
  forwarding_protocol = "HttpsOnly"

  https_redirect_enabled = false

  cdn_frontdoor_custom_domain_ids = [
    azurerm_cdn_frontdoor_custom_domain.resume.id
  ]
}
