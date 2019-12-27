variable "tenant_id" {
  type        = string
  description = "The AD tenant in which to provision resources"
}

variable "subscription_id" {
  type        = string
  description = "The Azure subscription in which to provision resources"
}

variable "client_id" {
  type        = string
  description = "The client id of the SP used to login"
}

variable "client_secret" {
  type        = string
  description = "The secret of the specified client id"
}

variable "storage_account_name" {
  type        = string
  description = "Used for the remote state data"
}

variable "storage_account_key" {
  type        = string
  description = "Used for the remote state data"
}

variable "workload" {
  type        = string
  description = "The workload we are deploying"
}

variable "prefix" {
  type        = string
  description = "Prefix for all the resources provisioned"
}

variable "region" {
  type        = string
  description = "The Azure region in which to provision resources"
}

variable "domain" {
  type        = string
  description = "The domain to use when configuring DNS and Traffic Manager"
}

variable "subdomain" {
  type        = string
  description = "The subdomain to use when configuring DNS and Traffic Manager"
}