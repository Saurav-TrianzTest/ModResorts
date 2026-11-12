#!/bin/bash
set -e
set -o pipefail

# Deploy script for modresorts to AWS EKS
# Runs from the repository root, never changes directory

PROJECT_NAME="modresorts"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
NAMESPACE="$IMAGE_NAME"

echo "=== ModResorts EKS Deployment ==="
echo "Namespace: $NAMESPACE"
echo ""

# Ask for AWS region
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
if [ -z "$AWS_REGION" ]; then
  echo "AWS region is required."
  exit 1
fi

# Ask for EKS cluster name
read -p "Enter EKS cluster name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "EKS cluster name is required."
  exit 1
fi

# Ask for image URI
read -p "Enter full image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "Image URI is required."
  exit 1
fi

# Ask for environment variables
echo ""
echo "=== Environment Variables ==="
echo "Enter values for the environment variables the application needs."
echo "Press Enter to skip (leave placeholder for manual configuration)."
echo ""

read -p "Enter value for JAVA_NAMING_FACTORY_INITIAL (or press Enter to skip): " JAVA_NAMING_FACTORY_INITIAL
read -p "Enter value for JAVA_NAMING_PROVIDER_URL (or press Enter to skip): " JAVA_NAMING_PROVIDER_URL

# Ask for WEATHER_API_KEY (credential)
echo ""
echo "=== Credentials ==="
echo "Enter values for credentials. Input will not be echoed."
echo ""
read -s -p "Enter WEATHER_API_KEY value (or press Enter to skip): " WEATHER_API_KEY
echo ""

# Configure kubectl for EKS
echo ""
echo "=== Configuring kubectl for EKS ==="
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
  echo "Failed to configure kubectl for EKS cluster."
  exit 1
fi
echo "kubectl configured successfully."
echo ""

# Verify cluster connectivity
echo "=== Verifying cluster connectivity ==="
kubectl cluster-info || exit 1
echo ""

# Create namespace
echo "=== Applying namespace ==="
kubectl apply -f kubernetes/namespace.yaml
echo "Namespace applied."
echo ""

# Create Secret for credentials
echo "=== Creating Kubernetes Secret ==="
SECRET_ARGS=""
if [ -n "$WEATHER_API_KEY" ]; then
  SECRET_ARGS="$SECRET_ARGS --from-literal=weather-api-key=$WEATHER_API_KEY"
fi

if [ -n "$SECRET_ARGS" ]; then
  kubectl create secret generic "$NAMESPACE-secrets" -n "$NAMESPACE" $SECRET_ARGS --dry-run=client -o yaml | kubectl apply -f -
  echo "Secret created."
else
  echo "No credentials provided. Skipping secret creation."
fi
echo ""

# Replace placeholders in deployment.yaml
echo "=== Preparing deployment manifest ==="
sed -i.bak 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{NAMESPACE}}|'"$NAMESPACE"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{JAVA_NAMING_FACTORY_INITIAL}}|'"${JAVA_NAMING_FACTORY_INITIAL:-}"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{JAVA_NAMING_PROVIDER_URL}}|'"${JAVA_NAMING_PROVIDER_URL:-}"'|g' kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

echo "Deployment manifest prepared."
echo ""

# Apply deployment
echo "=== Applying deployment ==="
kubectl apply -f kubernetes/deployment.yaml
echo "Deployment applied."
echo ""

# Apply service
echo "=== Applying service ==="
kubectl apply -f kubernetes/service.yaml
echo "Service applied."
echo ""

# Apply ingress
echo "=== Applying ingress ==="
kubectl apply -f kubernetes/ingress.yaml
echo "Ingress applied."
echo ""

# Wait for deployment rollout
echo "=== Waiting for deployment rollout ==="
kubectl rollout status deployment/"$IMAGE_NAME" -n "$NAMESPACE" --timeout=300s
echo ""

# Show resources
echo "=== Cluster Resources ==="
kubectl get pods,svc,ingress -n "$NAMESPACE"
echo ""

# Show application URL
echo "=== Application URL ==="
echo "Application will be available at: http://$NAMESPACE.example.com"
echo ""

echo "=== Deployment Complete ==="
echo ""
echo "Rollback instructions:"
echo "  kubectl rollout undo deployment/$IMAGE_NAME -n $NAMESPACE"
echo ""
echo "To check logs:"
echo "  kubectl logs -f deployment/$IMAGE_NAME -n $NAMESPACE"
