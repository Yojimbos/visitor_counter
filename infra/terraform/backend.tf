terraform {
  backend "azurerm" {
    resource_group_name  = "visitor-counter-rg"
    storage_account_name = "visitorcounterstate"
    container_name       = "tfstate"
    key                  = "visitor-counter.terraform.tfstate"
  }
}