#!/bin/bash
set -e
set -o pipefail

echo "=== ModResortsContainer Deployment Script (AWS EKS) ==="

# Project name
PROJECT_NAME="ModResortsContainer"
NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

# Ask for AWS EKS cluster details
read -p "Enter AWS region: " AWS_REGION
read -p "Enter EKS cluster name: " CLUSTER_NAME
read -p "Enter full image URI (registry/repo:tag): " IMAGE_URI

# Ask for environment variables
read -p "Enter value for WEATHER_API_KEY (or press Enter to skip): " WEATHER_API_KEY_VALUE

# Configure kubectl for the EKS cluster
echo "Configuring kubectl for EKS cluster..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo "Checking cluster connectivity..."
kubectl cluster-info || exit 1

# Create namespace
echo "Applying namespace..."
kubectl apply -f kubernetes/namespace.yaml

# Create Secret with credentials
echo "Creating Kubernetes Secret..."
SECRET_ARGS=""
if [ -n "$WEATHER_API_KEY_VALUE" ]; then
  SECRET_ARGS="--from-literal=weather-api-key=$WEATHER_API_KEY_VALUE"
fi

if [ -n "$SECRET_ARGS" ]; then
  kubectl create secret generic "${NAME}-secrets" -n "$NAME" $SECRET_ARGS --dry-run=client -o yaml | kubectl apply -f -
fi

# Deploy the application
echo "Deploying application..."
cp kubernetes/deployment.yaml /tmp/deployment.yaml.bak
sed -i.bak 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{NAME}}|'"$NAME"'|g' kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

kubectl apply -f kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

echo "Applying service..."
kubectl apply -f kubernetes/service.yaml

echo "Applying ingress..."
kubectl apply -f kubernetes/ingress.yaml

echo "Waiting for deployment rollout..."
kubectl rollout status deployment/"$NAME" -n "$NAME"

echo "Showing pods, services, and ingress..."
kubectl get pods,svc,ingress -n "$NAME"

echo "Application URL:"
kubectl get ingress -n "$NAME" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

echo ""
echo "=== Deployment complete ==="
echo "If deployment fails, rollback with:"
echo "  kubectl rollout undo deployment/$NAME -n $NAME"
