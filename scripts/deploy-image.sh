#!/bin/bash
set -e
set -o pipefail

PROJECT_NAME="ModResorts"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
NAMESPACE="$IMAGE_NAME"

echo "=== Deploy Image to AWS EKS ==="
echo ""

# Ask for AWS details
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
read -p "Enter EKS cluster name: " CLUSTER_NAME
read -p "Enter full image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:2.0.0): " IMAGE_URI

echo ""
echo "Configuring kubectl for EKS cluster..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || exit 1

echo ""
echo "=== Creating Kubernetes Secret ==="
# Ask for credential values
read -s -p "Enter WEATHER_API_KEY (or press Enter to skip): " WEATHER_API_KEY_VAL
echo ""

# Create secret with non-empty credentials
SECRET_ARGS=""
if [ -n "$WEATHER_API_KEY_VAL" ]; then
  SECRET_ARGS="--from-literal=weather-api-key=$WEATHER_API_KEY_VAL"
fi

if [ -n "$SECRET_ARGS" ]; then
  echo "Creating secret $NAMESPACE-secrets..."
  kubectl create secret generic "${NAMESPACE}-secrets" -n "$NAMESPACE" $SECRET_ARGS --dry-run=client -o yaml | kubectl apply -f -
else
  echo "No credentials provided, skipping secret creation."
fi

# Ask for non-credential environment variables
read -p "Enter JNDI_FACTORY (or press Enter to skip): " JNDI_FACTORY_VAL
read -p "Enter JNDI_PROVIDER_URL (or press Enter to skip): " JNDI_PROVIDER_URL_VAL

echo ""
echo "=== Applying Kubernetes manifests ==="

# Apply namespace
kubectl apply -f kubernetes/namespace.yaml

# Replace placeholders in deployment.yaml and apply
sed -i.bak "s|{{IMAGE_URI}}|${IMAGE_URI}|g" kubernetes/deployment.yaml
sed -i.bak "s|{{JNDI_FACTORY}}|${JNDI_FACTORY_VAL}|g" kubernetes/deployment.yaml
sed -i.bak "s|{{JNDI_PROVIDER_URL}}|${JNDI_PROVIDER_URL_VAL}|g" kubernetes/deployment.yaml

kubectl apply -f kubernetes/deployment.yaml

# Remove backup files
rm -f kubernetes/deployment.yaml.bak

# Apply service and ingress
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

echo ""
echo "=== Waiting for deployment rollout ==="
kubectl rollout status deployment/${NAMESPACE} -n "$NAMESPACE"

echo ""
echo "=== Deployment status ==="
kubectl get pods,svc,ingress -n "$NAMESPACE"

echo ""
echo "=== Application URL ==="
kubectl get ingress ${NAMESPACE}-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

echo ""
echo ""
echo "=== Deployment complete ==="
echo ""
echo "If the deployment fails, you can rollback with:"
echo "  kubectl rollout undo deployment/${NAMESPACE} -n ${NAMESPACE}"
