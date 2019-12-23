variable "armsubscriptionid" {}
variable "armclientid" {}
variable "armclientsecret" {}
variable "armtenantid" {}

provider "azurerm" {
  version = "=1.38.0"
  subscription_id = "${var.armsubscriptionid}"
  client_id       = "${var.armclientid}"
  client_secret   = "${var.armclientsecret}"
  tenant_id       = "${var.armtenantid}"
}

variable "tf_storageaccount" {}
variable "tf_container" {}
variable "tf_key" {}
variable "ARMACCESSKEY" {}

terraform {
  backend "azurerm" {
    storage_account_name  = "${var.tf_storageaccount}"
    container_name        = "${var.tf_container}"
    key                   = "${var.tf_key}"
    access_key            = "${var.ARMACCESSKEY}"
  }
}