$subscriptionId = "47275798-a588-41ab-8549-db17e66d49b9"
$resourceGroup  = "aks-rg"
$aksName        = "aks-cluster"
$identityName   = "azure-alb-identity"

az account set --subscription $subscriptionId

# Register required resource providers on Azure.
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking

# Install Azure CLI extensions.
az extension add --name alb

az aks update -g $resourceGroup -n $aksName --enable-oidc-issuer --enable-workload-identity --no-wait

$mcResourceGroup = az aks show `
 -g $resourceGroup `
 -n $aksName `
 --query nodeResourceGroup `
 -o tsv

$mcResourceGroupId = az group show `
 -n $mcResourceGroup `
 --query id `
 -o tsv

az identity create --resource-group $resourceGroup --name $identityName

$principalId = az identity show `
 -g $resourceGroup `
 -n $identityName `
 --query principalId `
 -o tsv


sleep 60

az role assignment create `
 --assignee-object-id $principalId `
 --assignee-principal-type ServicePrincipal `
 --role Reader `
 --scope $mcResourceGroupId `
 --subscription $subscriptionId

Write-Host "Setting up federation with AKS OIDC issuer..."

$AKS_OIDC_ISSUER = az aks show `
 -n $aksName `
 -g $resourceGroup `
 --query "oidcIssuerProfile.issuerUrl" `
 -o tsv

az identity federated-credential create `
 --name "azure-alb-identity" `
 --identity-name $identityName `
 --resource-group $resourceGroup `
 --issuer $AKS_OIDC_ISSUER `
 --subject "system:serviceaccount:azure-alb-system:alb-controller-sa"

# Namespaces
$HELM_NAMESPACE       = "alb-system"
$CONTROLLER_NAMESPACE = "azure-alb-system"


$CLIENT_ID = az identity show `
 -g $resourceGroup `
 -n $identityName `
 --query clientId `
 -o tsv

Write-Host "Managed identity client ID: $CLIENT_ID"

kubectl create namespace $HELM_NAMESPACE -o yaml --dry-run=client | kubectl apply -f -

Write-Host "Installing ALB Controller via Helm..."

helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller `
 --namespace $HELM_NAMESPACE `
 --version 1.8.12 `
 --set albController.namespace=$CONTROLLER_NAMESPACE `
 --set albController.podIdentity.clientID=$CLIENT_ID


#Verify the ALB Controller pods are ready:

#  kubectl get pods -n azure-alb-system

# You should see the following output:

# NAME	READY	STATUS	RESTARTS	AGE
# alb-controller-6648c5d5c-sdd9t	1/1	Running	0	4d6h
# alb-controller-6648c5d5c-au234	1/1	Running	0	4d6h

# Verify GatewayClass azure-alb-external is installed on your cluster:
#   kubectl get gatewayclass azure-alb-external -o yaml
