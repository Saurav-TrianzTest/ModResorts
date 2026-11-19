#!/bin/bash
set -e
set -o pipefail

PROJECT_NAME="ModResorts"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=== ModResorts EKS Deployment ==="
echo ""

read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
read -p "Enter EKS cluster name: " CLUSTER_NAME
read -p "Enter full image URI (registry/repository:tag): " IMAGE_URI

# Environment variables (non-credentials)
read -p "Enter value for JNDI_FACTORY (or press Enter to skip): " JNDI_FACTORY
read -p "Enter value for JNDI_PROVIDER_URL (or press Enter to skip): " JNDI_PROVIDER_URL
read -p "Enter value for HOSTNAME (or press Enter to skip): " HOSTNAME
read -p "Enter value for SERVER_NAME (or press Enter to skip): " SERVER_NAME

# Credentials (asked without echoing)
read -s -p "Enter value for WEATHER_API_KEY (or press Enter to skip): " WEATHER_API_KEY
echo ""
read -s -p "Enter value for CUSTOMER_INFO (or press Enter to skip): " CUSTOMER_INFO
echo ""

# Configure kubectl for the target EKS cluster
echo ""
echo "=== Configuring kubectl for EKS cluster ==="
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl cluster-info || exit 1

# Create the namespace
echo ""
echo "=== Applying namespace ==="
kubectl apply -f kubernetes/namespace.yaml

# Create the Secret for credentials
echo ""
echo "=== Creating Kubernetes Secret ==="
SECRET_ARGS=""
if [ -n "$WEATHER_API_KEY" ]; then
  SECRET_ARGS="$SECRET_ARGS --from-literal=weather-api-key=$WEATHER_API_KEY"
fi
if [ -n "$CUSTOMER_INFO" ]; then
  SECRET_ARGS="$SECRET_ARGS --from-literal=customer-info=$CUSTOMER_INFO"
fi

if [ -n "$SECRET_ARGS" ]; then
  kubectl create secret generic ${IMAGE_NAME}-secrets -n ${IMAGE_NAME} $SECRET_ARGS --dry-run=client -o yaml | kubectl apply -f -
fi

# Replace placeholders in deployment.yaml
echo ""
echo "=== Updating deployment manifest ==="
sed -i.bak 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{JNDI_FACTORY}}|'"${JNDI_FACTORY}"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{JNDI_PROVIDER_URL}}|'"${JNDI_PROVIDER_URL}"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{HOSTNAME}}|'"${HOSTNAME}"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{SERVER_NAME}}|'"${SERVER_NAME}"'|g' kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

# Apply deployment, service, and ingress
echo ""
echo "=== Applying deployment ==="
kubectl apply -f kubernetes/deployment.yaml

echo ""
echo "=== Applying service ==="
kubectl apply -f kubernetes/service.yaml

echo ""
echo "=== Applying ingress ==="
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
echo ""
echo "=== Waiting for deployment rollout ==="
kubectl rollout status deployment/${IMAGE_NAME} -n ${IMAGE_NAME}

# Show resources
echo ""
echo "=== Deployed resources ==="
kubectl get pods,svc,ingress -n ${IMAGE_NAME}

# Show application URL
echo ""
echo "=== Application URL ==="
echo "https://${IMAGE_NAME}.example.com"

echo ""
echo "=== Deployment complete ==="
echo "If you need to rollback, run:"
echo "  kubectl rollout undo deployment/${IMAGE_NAME} -n ${IMAGE_NAME}"
