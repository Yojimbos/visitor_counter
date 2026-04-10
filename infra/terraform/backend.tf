terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateanst20260410"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}