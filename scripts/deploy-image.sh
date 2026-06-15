#!/bin/bash
set -e
set -o pipefail

APP_NAME="modresorts"
NAMESPACE="modresorts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
echo "--- Optional Application Environment Variables ---"
echo "(Press Enter to skip any variable)"
echo ""

read -p "Enter WEATHER_API_KEY value (or press Enter to skip): " WEATHER_API_KEY_VAL
read -p "Enter SERVER_DISPLAY_NAME value (or press Enter to skip, default: modresorts-server): " SERVER_DISPLAY_NAME_VAL
read -p "Enter SERVER_FULL_NAME value (or press Enter to skip, default: modresorts-server/default): " SERVER_FULL_NAME_VAL
read -p "Enter JNDI_PROVIDER_URL value (or press Enter to skip): " JNDI_PROVIDER_URL_VAL
read -p "Enter DB_URL value (or press Enter to skip): " DB_URL_VAL
read -p "Enter DB_USERNAME value (or press Enter to skip): " DB_USERNAME_VAL
read -p "Enter DB_PASSWORD value (or press Enter to skip): " DB_PASSWORD_VAL

# Set defaults for optional vars
[ -z "$SERVER_DISPLAY_NAME_VAL" ] && SERVER_DISPLAY_NAME_VAL="modresorts-server"
[ -z "$SERVER_FULL_NAME_VAL" ] && SERVER_FULL_NAME_VAL="modresorts-server/default"

echo ""
echo "Configuring kubectl for EKS cluster: $CLUSTER_NAME in $AWS_REGION ..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to configure kubectl for EKS cluster."
  exit 1
fi

echo ""
echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to Kubernetes cluster."; exit 1; }

echo ""
echo "Updating Kubernetes manifests with deployment values..."

# Work on copies to avoid modifying originals
cp -r "$PROJECT_ROOT/kubernetes" /tmp/modresorts-k8s-deploy

# Replace all placeholders using pipe delimiter
sed -i 's|{{IMAGE_URI}}|'"$IMAGE_URI"'|g'                           /tmp/modresorts-k8s-deploy/deployment.yaml
sed -i 's|{{WEATHER_API_KEY}}|'"$WEATHER_API_KEY_VAL"'|g'           /tmp/modresorts-k8s-deploy/deployment.yaml
sed -i 's|{{SERVER_DISPLAY_NAME}}|'"$SERVER_DISPLAY_NAME_VAL"'|g'   /tmp/modresorts-k8s-deploy/deployment.yaml
sed -i 's|{{SERVER_FULL_NAME}}|'"$SERVER_FULL_NAME_VAL"'|g'         /tmp/modresorts-k8s-deploy/deployment.yaml
sed -i 's|{{JNDI_PROVIDER_URL}}|'"$JNDI_PROVIDER_URL_VAL"'|g'       /tmp/modresorts-k8s-deploy/deployment.yaml
sed -i 's|{{DB_URL}}|'"$DB_URL_VAL"'|g'                             /tmp/modresorts-k8s-deploy/deployment.yaml
sed -i 's|{{DB_USERNAME}}|'"$DB_USERNAME_VAL"'|g'                   /tmp/modresorts-k8s-deploy/deployment.yaml
sed -i 's|{{DB_PASSWORD}}|'"$DB_PASSWORD_VAL"'|g'                   /tmp/modresorts-k8s-deploy/deployment.yaml

echo ""
echo "Applying Kubernetes manifests..."

echo "  [1/4] Applying namespace..."
kubectl apply -f /tmp/modresorts-k8s-deploy/namespace.yaml

echo "  [2/4] Applying deployment..."
kubectl apply -f /tmp/modresorts-k8s-deploy/deployment.yaml

echo "  [3/4] Applying service..."
kubectl apply -f /tmp/modresorts-k8s-deploy/service.yaml

echo "  [4/4] Applying ingress..."
kubectl apply -f /tmp/modresorts-k8s-deploy/ingress.yaml

echo ""
echo "Waiting for deployment rollout to complete..."
kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed or timed out."
  echo "To rollback, run: kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE"
  exit 1
fi

echo ""
echo "Verifying deployed resources..."
kubectl get pods,svc,ingress -n $NAMESPACE

echo ""
echo "Fetching application URL from ingress..."
INGRESS_HOST=$(kubectl get ingress modresorts-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [ "$INGRESS_HOST" != "pending" ] && [ -n "$INGRESS_HOST" ]; then
  echo "Application URL: http://$INGRESS_HOST/resorts/"
else
  echo "Ingress hostname is still pending. Run the following to check later:"
  echo "  kubectl get ingress modresorts-ingress -n $NAMESPACE"
fi

# Cleanup temp files
rm -rf /tmp/modresorts-k8s-deploy

echo ""
echo "============================================"
echo "  SUCCESS: ModResorts deployed to EKS!"
echo "============================================"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f deployment/$APP_NAME -n $NAMESPACE"
echo "  kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE  # rollback"
