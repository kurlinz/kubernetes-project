rg                   = "test-rg"
location             = "germanywestcentral"
vnet_name            = "test-vnet"
vnet_address_space   = ["10.10.0.0/16"]
subnet_name          = "test-subnet"
subnet_address_space = ["10.10.1.0/24"]
tags = {
  "env" = "test"
}
aks-name            = "test-aks-cluster"
node_pool_name      = "testnodepool"
min_count           = 1
max_count           = 4
auto_scaling        = true
vm_size             = "Standard_DS2_v2"
username            = "azureuser"
enable_azure_policy = true
aks_tags = {
  "env" = "test"
}
