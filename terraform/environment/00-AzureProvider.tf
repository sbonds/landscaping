variable "armsubscriptionid" {
}

variable "armclientid" {
}

variable "armclientsecret" {
}

variable "armtenantid" {
}

provider "azurerm" {
  version         = "=1.38.0"
  subscription_id = var.armsubscriptionid
  client_id       = var.armclientid
  client_secret   = var.armclientsecret
  tenant_id       = var.armtenantid
}

terraform {
  backend "azurerm" {
    storage_account_name = "vmchooserterraform"
    container_name       = "notset"
    key                  = "terraform.tfstate"
  }
}

