#!/bin/bash

# Deploy Application Gateway for Containers "ALB Controller" using AKS Add-on

# Sign in to your Azure subscription.
SUBSCRIPTION_ID='<your subscription id>'
az login
az account set --subscription $SUBSCRIPTION_ID

# Register required resource providers on Azure.
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking

# Install Azure CLI extensions.
az extension add --name alb
az extension add --name aks-preview

# Register add-on features.
# Register required preview features
az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
az feature register --namespace "Microsoft.ContainerService" --name "ApplicationLoadBalancerPreview"

# If using an existing cluster, ensure you enable Workload Identity support on your AKS cluster.
AKS_NAME='<your cluster name>'
RESOURCE_GROUP='<your resource group name>'
az aks update -g $RESOURCE_GROUP -n $AKS_NAME --enable-oidc-issuer --enable-workload-identity --no-wait


# Update the AKS cluster
az aks update --name ${AKS_NAME} --resource-group ${RESOURCE_GROUP} --enable-gateway-api --enable-application-load-balancer


# Verify the ALB Controller pods are running in the kube-system namespace
kubectl get pods -n kube-system | grep alb-controller
