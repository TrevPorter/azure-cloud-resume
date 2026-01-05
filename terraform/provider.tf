terraform {
  required_version = ">= 1.5"

  backend "azurerm" {
    resource_group_name  = "rg-tf-state"
    storage_account_name = "tptfstate01"
    container_name       = "tfstate"
    key                  = "cloud-resume.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}
