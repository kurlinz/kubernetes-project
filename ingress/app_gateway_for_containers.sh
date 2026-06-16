#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1

SUBSCRIPTION_ID="47275798-a588-41ab-8549-db17e66d49b9"
RESOURCE_GROUP="test-rg"
AKS_NAME="test-aks-cluster"
VNET_RESOURCE_GROUP="test-rg"
VNET_NAME="test-vnet"
SUBNET_ADDRESS_PREFIX="10.10.3.0/24"
ALB_SUBNET_NAME="subnet-alb"
IDENTITY_RESOURCE_NAME="azure-alb-identity"

echo "[1/6] Setting active Azure subscription to $SUBSCRIPTION_ID..."
az account set --subscription "$SUBSCRIPTION_ID"
echo "      Done."

echo "[2/6] Checking ALB subnet '$ALB_SUBNET_NAME'..."
ALB_SUBNET_ID=$(az network vnet subnet show \
  --name "$ALB_SUBNET_NAME" \
  --resource-group "$VNET_RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --query id \
  --output tsv 2>/dev/null | tr -d '\r' || true)

if [[ -n "$ALB_SUBNET_ID" ]]; then
  echo "      Already exists — skipping."
else
  echo "      Creating subnet..."
  az network vnet subnet create \
    --resource-group "$VNET_RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$ALB_SUBNET_NAME" \
    --address-prefixes "$SUBNET_ADDRESS_PREFIX" \
    --delegations 'Microsoft.ServiceNetworking/trafficControllers'

  ALB_SUBNET_ID=$(az network vnet subnet show \
    --name "$ALB_SUBNET_NAME" \
    --resource-group "$VNET_RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --query id \
    --output tsv | tr -d '\r')
  echo "      Done."
fi
echo "      Subnet ID: $ALB_SUBNET_ID"

echo "[3/6] Retrieving AKS node resource group details..."
MC_RESOURCE_GROUP=$(az aks show \
  --name "$AKS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "nodeResourceGroup" \
  -o tsv | tr -d '\r')

MC_RESOURCE_GROUP_ID=$(az group show \
  --name "$MC_RESOURCE_GROUP" \
  --query id \
  -o tsv | tr -d '\r')

if [[ -z "$MC_RESOURCE_GROUP" || -z "$MC_RESOURCE_GROUP_ID" ]]; then
  echo "ERROR: Could not retrieve AKS node resource group details. Aborting." >&2
  exit 1
fi
echo "      Node resource group: $MC_RESOURCE_GROUP"
echo "      Node resource group ID: $MC_RESOURCE_GROUP_ID"

echo "[4/6] Retrieving managed identity principal ID..."
PRINCIPAL_ID=$(az identity show \
  -g "$RESOURCE_GROUP" \
  -n "$IDENTITY_RESOURCE_NAME" \
  --query principalId \
  -o tsv | tr -d '\r' || true)

if [[ -z "$PRINCIPAL_ID" ]]; then
  echo "ERROR: Managed identity '$IDENTITY_RESOURCE_NAME' not found in '$RESOURCE_GROUP'. Run alb_controller.sh first." >&2
  exit 1
fi
echo "      Principal ID: $PRINCIPAL_ID"

echo "[5/6] Checking AppGw Configuration Manager role on node resource group..."
echo "      Scope: $MC_RESOURCE_GROUP_ID"
ROLE_OUTPUT1=$(az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --scope "$MC_RESOURCE_GROUP_ID" \
  --role "fbc52c3f-28ad-4303-a892-8a056630b8f1" 2>&1 || true)

if echo "$ROLE_OUTPUT1" | grep -qi "RoleAssignmentExists"; then
  echo "      Already assigned — skipping."
elif echo "$ROLE_OUTPUT1" | grep -qi '"id":'; then
  echo "      Done."
else
  echo "ERROR: Role assignment failed:" >&2
  echo "$ROLE_OUTPUT1" >&2
  exit 1
fi

echo "[6/6] Checking Network Contributor role on ALB subnet..."
echo "      Scope: $ALB_SUBNET_ID"
ROLE_OUTPUT2=$(az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --scope "$ALB_SUBNET_ID" \
  --role "4d97b98b-1d4f-4787-a291-c67834d212e7" 2>&1 || true)

if echo "$ROLE_OUTPUT2" | grep -qi "RoleAssignmentExists"; then
  echo "      Already assigned — skipping."
elif echo "$ROLE_OUTPUT2" | grep -qi '"id":'; then
  echo "      Done."
else
  echo "ERROR: Role assignment failed:" >&2
  echo "$ROLE_OUTPUT2" >&2
  exit 1
fi

echo ""
echo "Application Gateway for Containers setup complete."
echo ""
echo "Next steps — apply the Kubernetes resources:"
echo "  kubectl apply -f gw_class_ns.yaml"
echo " kubectl apply -f app_lb_gw.yaml"
echo ""
echo "Then validate:"
echo "  kubectl get applicationloadbalancer alb-test -n alb-test-infra -o yaml -w"
