#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

#Visit this page for reference and instructions on how to set up the ALB Controller for AKS clusters:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon?tabs=azure-cli%2Cazure-cli2
SUBSCRIPTION_ID=""
RESOURCE_GROUP="test-rg"
AKS_NAME="test-aks-cluster"
IDENTITY_NAME="azure-alb-identity"
HELM_NAMESPACE="alb-system"
CONTROLLER_NAMESPACE="azure-alb-system"

echo "[1/9] Setting active Azure subscription to $SUBSCRIPTION_ID..."
az account set --subscription "$SUBSCRIPTION_ID"
echo "      Done."

echo "[2/9] Registering required Azure resource providers..."
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking
echo "      Done. (Registration may still be propagating in the background.)"

echo "[3/9] Checking Azure CLI ALB extension..."
if az extension show --name alb &>/dev/null; then
  echo "      Already installed — skipping."
else
  az extension add --name alb
  echo "      Done."
fi

echo "[4/9] Retrieving AKS node resource group details..."
MC_RESOURCE_GROUP=$(az aks show \
  -g "$RESOURCE_GROUP" \
  -n "$AKS_NAME" \
  --query nodeResourceGroup \
  -o tsv | tr -d '\r')

MC_RESOURCE_GROUP_ID=$(az group show \
  -n "$MC_RESOURCE_GROUP" \
  --query id \
  -o tsv | tr -d '\r')

if [[ -z "$MC_RESOURCE_GROUP" || -z "$MC_RESOURCE_GROUP_ID" ]]; then
  echo "ERROR: Could not retrieve AKS node resource group details. Aborting." >&2
  exit 1
fi
echo "      Node resource group: $MC_RESOURCE_GROUP"
echo "      Node resource group ID: $MC_RESOURCE_GROUP_ID"

echo "[5/9] Checking managed identity '$IDENTITY_NAME'..."
if az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" &>/dev/null; then
  echo "      Already exists — skipping creation."
else
  az identity create --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME"
  echo "      Created. Waiting 60 seconds for identity to propagate in Azure AD..."
  sleep 60
fi

PRINCIPAL_ID=$(az identity show \
  -g "$RESOURCE_GROUP" \
  -n "$IDENTITY_NAME" \
  --query principalId \
  -o tsv | tr -d '\r')
CLIENT_ID=$(az identity show \
  -g "$RESOURCE_GROUP" \
  -n "$IDENTITY_NAME" \
  --query clientId \
  -o tsv | tr -d '\r')
echo "      Principal ID: $PRINCIPAL_ID"
echo "      Client ID:    $CLIENT_ID"

echo "[6/9] Checking Reader role assignment on node resource group..."
echo "      Scope: $MC_RESOURCE_GROUP_ID"
ROLE_OUTPUT=$(az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Reader \
  --scope "$MC_RESOURCE_GROUP_ID" 2>&1 || true)

if echo "$ROLE_OUTPUT" | grep -qi "RoleAssignmentExists"; then
  echo "      Already assigned — skipping."
elif echo "$ROLE_OUTPUT" | grep -qi '"id":'; then
  echo "      Done."
else
  echo "ERROR: Role assignment failed:" >&2
  echo "$ROLE_OUTPUT" >&2
  exit 1
fi

echo "[7/9] Checking federated credential for ALB controller..."
AKS_OIDC_ISSUER=$(az aks show \
  -n "$AKS_NAME" \
  -g "$RESOURCE_GROUP" \
  --query "oidcIssuerProfile.issuerUrl" \
  -o tsv | tr -d '\r')
echo "      OIDC issuer: $AKS_OIDC_ISSUER"

if az identity federated-credential show \
  --name "azure-alb-identity" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "      Already exists — skipping."
else
  az identity federated-credential create \
    --name "azure-alb-identity" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --issuer "$AKS_OIDC_ISSUER" \
    --subject "system:serviceaccount:azure-alb-system:alb-controller-sa"
  echo "      Done."
fi

echo "[8/9] Checking Kubernetes namespace '$HELM_NAMESPACE'..."
kubectl create namespace "$HELM_NAMESPACE" -o yaml --dry-run=client | kubectl apply -f -
echo "      Done."

echo "[9/9] Checking ALB Controller Helm release..."
if helm status alb-controller --namespace "$HELM_NAMESPACE" &>/dev/null; then
  echo "      Already installed — skipping."
else
  helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
    --namespace "$HELM_NAMESPACE" \
    --version 1.8.12 \
    --set albController.namespace="$CONTROLLER_NAMESPACE" \
    --set albController.podIdentity.clientID="$CLIENT_ID"
  echo "      Done."
fi

echo ""
echo "ALB Controller setup complete."
echo ""
echo "Verify the ALB Controller pods are ready"
kubectl get pods -n azure-alb-system

echo "Verify GatewayClass azure-alb-external is installed on your cluster:"
kubectl get gatewayclass azure-alb-external -o yaml
