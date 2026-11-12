#!/bin/bash
set -e
set -o pipefail

IMAGE_NAME="modresortsconatinr"

echo "=== Deploy $IMAGE_NAME to AWS EKS ==="

# Ask for AWS region and cluster name
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
read -p "Enter EKS cluster name: " CLUSTER_NAME
read -p "Enter IMAGE_URI (full path with registry and tag): " IMAGE_URI

# Ask for environment variables
read -p "Enter value for JAVA_NAMING_FACTORY_INITIAL (or press Enter to skip): " VAR_JAVA_NAMING_FACTORY_INITIAL
read -p "Enter value for JAVA_NAMING_PROVIDER_URL (or press Enter to skip): " VAR_JAVA_NAMING_PROVIDER_URL
read -p "Enter value for DATASOURCE_JNDI (or press Enter to skip): " VAR_DATASOURCE_JNDI

# Ask for credentials (without echoing)
read -s -p "Enter WEATHER_API_KEY (or press Enter to skip): " VAR_WEATHER_API_KEY
echo ""

# Configure kubectl for the EKS cluster
echo "=== Configuring kubectl for EKS cluster ==="
if ! aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"; then
  echo "Failed to configure kubectl for EKS cluster"
  exit 1
fi

# Check cluster connectivity
echo "=== Checking cluster connectivity ==="
if ! kubectl cluster-info; then
  echo "Cluster connectivity check failed"
  exit 1
fi

# Apply namespace
echo "=== Applying namespace ==="
if ! kubectl apply -f kubernetes/namespace.yaml; then
  echo "Failed to apply namespace"
  exit 1
fi

# Create Secret for credentials
echo "=== Creating Kubernetes Secret ==="
SECRET_ARGS=""
if [ -n "$VAR_WEATHER_API_KEY" ]; then
  SECRET_ARGS="$SECRET_ARGS --from-literal=weather-api-key=$VAR_WEATHER_API_KEY"
fi

if [ -n "$SECRET_ARGS" ]; then
  if ! kubectl create secret generic ${IMAGE_NAME}-secrets -n ${IMAGE_NAME} $SECRET_ARGS --dry-run=client -o yaml | kubectl apply -f -; then
    echo "Failed to create Kubernetes Secret"
    exit 1
  fi
fi

# Replace placeholders in deployment.yaml
echo "=== Deploying application ==="
sed -i.bak "s|{{IMAGE_URI}}|$IMAGE_URI|g" kubernetes/deployment.yaml
sed -i.bak "s|{{JAVA_NAMING_FACTORY_INITIAL}}|${VAR_JAVA_NAMING_FACTORY_INITIAL}|g" kubernetes/deployment.yaml
sed -i.bak "s|{{JAVA_NAMING_PROVIDER_URL}}|${VAR_JAVA_NAMING_PROVIDER_URL}|g" kubernetes/deployment.yaml
sed -i.bak "s|{{DATASOURCE_JNDI}}|${VAR_DATASOURCE_JNDI}|g" kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

if [ ! -f kubernetes/deployment.yaml ]; then
  echo "Failed to update deployment.yaml"
  exit 1
fi

# Apply deployment
if ! kubectl apply -f kubernetes/deployment.yaml; then
  echo "Failed to apply deployment"
  exit 1
fi

# Apply service and ingress
if ! kubectl apply -f kubernetes/service.yaml; then
  echo "Failed to apply service"
  exit 1
fi

if ! kubectl apply -f kubernetes/ingress.yaml; then
  echo "Failed to apply ingress"
  exit 1
fi

# Wait for deployment to be ready
echo "=== Waiting for deployment to be ready ==="
if ! kubectl rollout status deployment/${IMAGE_NAME} -n ${IMAGE_NAME}; then
  echo "Deployment rollout failed"
  echo "Rollback with: kubectl rollout undo deployment/${IMAGE_NAME} -n ${IMAGE_NAME}"
  exit 1
fi

# Show resources
echo "=== Deployment status ==="
kubectl get pods,svc,ingress -n ${IMAGE_NAME}

# Show application URL
echo "=== Application URL ==="
kubectl get ingress ${IMAGE_NAME}-ingress -n ${IMAGE_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

echo ""
echo "=== Deployment complete ==="
echo "If something went wrong, rollback with:"
echo "  kubectl rollout undo deployment/${IMAGE_NAME} -n ${IMAGE_NAME}"
