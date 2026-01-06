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

  patterns_to_match      = ["/*"]
  supported_protocols    = ["Https"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true

  cdn_frontdoor_custom_domain_ids = [
    azurerm_cdn_frontdoor_custom_domain.resume.id
  ]
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

