#Prepare your virtual network / subnet for Application Gateway for Containers

$VNET_RESOURCE_GROUP = "aks-rg"
$VNET_NAME = "aks-vnet"
$SUBNET_ADDRESS_PREFIX = "10.241.0.0/24"
$ALB_SUBNET_NAME = "subnet-alb"
$IDENTITY_RESOURCE_NAME = "azure-alb-identity"
$aksName        = "aks-cluster"
$resourceGroup  = "aks-rg"

az network vnet subnet create --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --name $ALB_SUBNET_NAME --address-prefixes $SUBNET_ADDRESS_PREFIX --delegations 'Microsoft.ServiceNetworking/trafficControllers'

$ALB_SUBNET_ID = $(az network vnet subnet show --name $ALB_SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --query '[id]' --output tsv)

#Delegate permissions to managed identity

$MC_RESOURCE_GROUP = az aks show `
 --name $aksName `
 --resource-group $resourceGroup `
 --query "nodeResourceGroup" `
 -o tsv


# Get MC_ resource group ID
$mcResourceGroupId = az group show `
 --name $MC_RESOURCE_GROUP `
 --query id `
 -o tsv


# Get managed identity principal ID
$principalId = az identity show `
 -g $resourceGroup `
 -n $IDENTITY_RESOURCE_NAME `
 --query principalId `
 -o tsv


# Delegate AppGw for Containers Configuration Manager role to AKS Managed Cluster RG
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $mcResourceGroupId --role "fbc52c3f-28ad-4303-a892-8a056630b8f1"

# Delegate Network Contributor permission for join to association subnet
az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $ALB_SUBNET_ID --role "4d97b98b-1d4f-4787-a291-c67834d212e7"

#Create ApplicationLoadBalancer Kubernetes resource
#Define the Kubernetes namespace for the ApplicationLoadBalancer resource
#Check the app_lb_namespace.yaml file
# kubectl apply -f - <<EOF
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: alb-test-infra
# EOF

#create the Application Gateway for Containers resource and association.
#Check the app_gw_for_containers file
# kubectl apply -f - <<EOF
# apiVersion: alb.networking.azure.io/v1
# kind: ApplicationLoadBalancer
# metadata:
#   name: alb-test
#   namespace: alb-test-infra
# spec:
#   associations:
#   - $ALB_SUBNET_ID
# EOF


#Validate creation

kubectl get applicationloadbalancer alb-test -n alb-test-infra -o yaml -w


