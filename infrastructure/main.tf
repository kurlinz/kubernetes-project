module "resource-group" {
  source   = "git::https://github.com/kurlinz/Terraform-Projects.git//modules/Resource-Group"
  name     = var.rg
  location = var.location
  tags     = var.tags
}
module "vnet" {
  source               = "git::https://github.com/kurlinz/Terraform-Projects.git//modules/Vnet"
  Vnet_name            = var.vnet_name
  location             = module.resource-group.location
  resource_group_name  = module.resource-group.name
  vnet_address_space   = var.vnet_address_space
  subnet_name          = var.subnet_name
  subnet_address_space = var.subnet_address_space
}
module "ssh-key" {
  source                  = "git::https://github.com/kurlinz/Terraform-Projects.git//modules/ssh-key"
  resource_group_id       = module.resource-group.id
  resource_group_location = module.resource-group.location
}

module "aks" {
  source              = "git::https://github.com/kurlinz/Terraform-Projects.git//modules/aks"
  resource_group_name = module.resource-group.name
  location            = module.resource-group.location
  cluster_name        = var.aks-name
  admin_username      = var.username
  node-pool-name      = var.node_pool_name
  node-pool-vm-size   = var.vm_size
  ssh_key             = module.ssh-key.key_data
  vnet_subnet_id      = module.vnet.subnet_id
  min_count           = var.min_count
  max_count           = var.max_count
  auto_scaling        = var.auto_scaling

}