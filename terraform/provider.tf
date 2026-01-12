terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.96.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tf-state"
    storage_account_name = "tptfstate01"
    container_name       = "tfstate"
    key                  = "cloud-resume.tfstate"
  }
}

provider "azurerm" {
  features {}

  subscription_id = "f375afbd-e722-474f-9d5f-5f44a25ed424"
}

