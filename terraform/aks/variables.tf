variable "tenant_id" {
  type        = string
  description = "The AD tenant in which to provision resources"
}

variable "subscription_id" {
  type        = string
  description = "The Azure subscription in which to provision resources"
}

variable "object_id" {
  type        = string
  description = "The object id of the SP used to login"
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

variable "aks_sku" {
  type        = string
  default     = "Standard_B2ms"
  description = "Machine sku used for node pool"
}

variable "aks_count" {
  type        = number
  default     = 1
  description = "Initial node pool siwe"
}

variable "aks_count_min" {
  type        = number
  default     = 1
  description = "Min node pool size"
}

variable "aks_count_max" {
  type        = number
  default     = 10
  description = "Max node pool size"
}

variable "aks_os_disk" {
  type        = number
  default     = 30
  description = "Size of OS disk on node"
}

variable "aks_os_type" {
  type        = string
  default     = "Linux"
  description = "Node os type"
}