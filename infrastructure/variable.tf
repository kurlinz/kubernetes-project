variable "rg" {
  type = string
}
variable "location" {
  type = string
}
variable "tags" {
  type = map(string)
}
variable "vnet_name" {
  type = string
}
variable "vnet_address_space" {
  type = tuple([string])
}
variable "subnet_name" {
  type = string
}
variable "subnet_address_space" {
  type = tuple([string])
}
variable "aks-name" {
  type = string
}
variable "node_pool_name" {
  type = string
}
variable "min_count" {
  type = number
}
variable "max_count" {
  type = number
}
variable "vm_size" {
  type    = string
  default = "Standard_D2_v2"
}
variable "username" {
  type = string
}
variable "enable_azure_policy" {
  type = bool
}
variable "aks_tags" {
  type = map(string)
}
variable "auto_scaling" {
  type        = bool
  description = "Enable auto-scaling for the node pool."
}
