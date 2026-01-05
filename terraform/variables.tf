variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "australiaeast"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "tp-cloud-resume"
}

variable "storage_account_name" {
  description = "Globally unique storage account name"
  type        = string
}

variable "cdn_profile_name" {
  description = "Azure CDN profile name"
  type        = string
  default     = "cdn-cloud-resume"
}

variable "cdn_endpoint_name" {
  description = "Azure CDN endpoint name"
  type        = string
  default     = "resume-endpoint"
}
