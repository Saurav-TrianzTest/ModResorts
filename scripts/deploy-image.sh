#!/bin/bash
set -e
set -o pipefail

APP_NAME="modresorts"
NAMESPACE="modresorts"

echo "============================================"
echo "  ModResorts - Deploy to AWS EKS"
echo "============================================"
echo ""

# Prompt for AWS region
read -p "Enter AWS Region (e.g. us-east-1): " AWS_REGION
if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS Region is required."
  exit 1
fi

# Prompt for EKS cluster name
read -p "Enter EKS Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: EKS Cluster Name is required."
  exit 1
fi

# Prompt for Docker image URI
read -p "Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

echo ""
echo "--- Optional Environment Variable Configuration ---"
read -p "Enter value for WEATHER_API_KEY (or press Enter to skip): " WEATHER_API_KEY_VAL
read -p "Enter value for SERVER_DISPLAY_NAME (or press Enter to skip): " SERVER_DISPLAY_NAME_VAL
read -p "Enter value for SERVER_FULL_NAME (or press Enter to skip): " SERVER_FULL_NAME_VAL

echo ""
echo "Configuring kubectl for EKS cluster: $CLUSTER_NAME in region: $AWS_REGION"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to configure kubectl for EKS cluster."
  exit 1
fi

echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to Kubernetes cluster."; exit 1; }

echo ""
echo "Updating Kubernetes manifests with provided values..."

# Work on copies to avoid modifying originals permanently
cp kubernetes/deployment.yaml kubernetes/deployment.yaml.bak

# Replace placeholders using pipe delimiter
sed -i 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g' kubernetes/deployment.yaml

if [ -n "$WEATHER_API_KEY_VAL" ]; then
  sed -i 's|{{WEATHER_API_KEY}}|'"$WEATHER_API_KEY_VAL"'|g' kubernetes/deployment.yaml
else
  sed -i 's|{{WEATHER_API_KEY}}||g' kubernetes/deployment.yaml
fi

if [ -n "$SERVER_DISPLAY_NAME_VAL" ]; then
  sed -i 's|{{SERVER_DISPLAY_NAME}}|'"$SERVER_DISPLAY_NAME_VAL"'|g' kubernetes/deployment.yaml
else
  sed -i 's|{{SERVER_DISPLAY_NAME}}|modresorts-container|g' kubernetes/deployment.yaml
fi

if [ -n "$SERVER_FULL_NAME_VAL" ]; then
  sed -i 's|{{SERVER_FULL_NAME}}|'"$SERVER_FULL_NAME_VAL"'|g' kubernetes/deployment.yaml
else
  sed -i 's|{{SERVER_FULL_NAME}}|modresorts-container-01|g' kubernetes/deployment.yaml
fi

echo ""
echo "Applying Kubernetes manifests..."

echo "  [1/4] Applying namespace..."
kubectl apply -f kubernetes/namespace.yaml

echo "  [2/4] Applying deployment..."
kubectl apply -f kubernetes/deployment.yaml

echo "  [3/4] Applying service..."
kubectl apply -f kubernetes/service.yaml

echo "  [4/4] Applying ingress..."
kubectl apply -f kubernetes/ingress.yaml

# Restore original deployment.yaml
mv kubernetes/deployment.yaml.bak kubernetes/deployment.yaml

echo ""
echo "Waiting for deployment rollout..."
kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed. Running rollback..."
  kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE
  echo "Rollback initiated. Check pod status with: kubectl get pods -n $NAMESPACE"
  exit 1
fi

echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n $NAMESPACE

echo ""
echo "============================================"
echo "  Deployment completed successfully!"
echo ""
INGRESS_HOST=$(kubectl get ingress modresorts-ingress -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "modresorts.example.com")
echo "  Application URL: http://$INGRESS_HOST"
echo ""
echo "  Useful commands:"
echo "    kubectl get pods -n $NAMESPACE"
echo "    kubectl logs -f deployment/$APP_NAME -n $NAMESPACE"
echo "    kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE  # rollback"
echo "============================================"
