#!/bin/bash
# Deploys the pushed ContainerSanity image to AWS EKS with kubectl.
# Run from the repository root:  ./scripts/deploy-image.sh
set -e
set -o pipefail

APP_NAME="containersanity"
NAMESPACE="containersanity"
SECRET_NAME="${APP_NAME}-secrets"

command -v aws >/dev/null 2>&1 || { echo "ERROR: the AWS CLI is not installed"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed"; exit 1; }

# The manifests hold {{PLACEHOLDERS}}: keep the templates and restore them on exit
BACKUP_DIR=$(mktemp -d)
cp kubernetes/deployment.yaml "$BACKUP_DIR/deployment.yaml"
restore_templates() {
  cp "$BACKUP_DIR/deployment.yaml" kubernetes/deployment.yaml
  rm -f kubernetes/deployment.yaml.bak
  rm -rf "$BACKUP_DIR"
}
trap restore_templates EXIT

# Escapes the characters that are special in a sed replacement with a pipe delimiter
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

echo "=== Deploy ${APP_NAME} to AWS EKS ==="
read -r -p "Enter the AWS region (for example us-east-1): " AWS_REGION
read -r -p "Enter the EKS cluster name: " CLUSTER_NAME
read -r -p "Enter the image URI (registry/repository:tag): " IMAGE_URI
if [ -z "$AWS_REGION" ] || [ -z "$CLUSTER_NAME" ] || [ -z "$IMAGE_URI" ]; then
  echo "ERROR: the region, the cluster name and the image URI are required"
  exit 1
fi

read -r -p "Enter value for JNDI_INITIAL_CONTEXT_FACTORY (or press Enter to skip): " JNDI_INITIAL_CONTEXT_FACTORY
read -r -p "Enter value for JNDI_PROVIDER_URL (or press Enter to skip): " JNDI_PROVIDER_URL
read -r -s -p "Enter value for WEATHER_API_KEY (or press Enter to skip; the application then serves its default weather data): " WEATHER_API_KEY
echo ""

echo "Step 1: configuring kubectl for the cluster..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" || { echo "ERROR: aws eks update-kubeconfig failed"; exit 1; }
kubectl cluster-info || exit 1

echo "Step 2: filling in the placeholders of kubernetes/deployment.yaml..."
IMAGE_URI_ESC=$(sed_escape "$IMAGE_URI")
sed -i.bak "s|{{IMAGE_URI}}|${IMAGE_URI_ESC}|g" kubernetes/deployment.yaml
sed -i.bak "s|{{NAMESPACE}}|${NAMESPACE}|g" kubernetes/deployment.yaml
sed -i.bak "s|{{JNDI_INITIAL_CONTEXT_FACTORY}}|$(sed_escape "$JNDI_INITIAL_CONTEXT_FACTORY")|g" kubernetes/deployment.yaml
sed -i.bak "s|{{JNDI_PROVIDER_URL}}|$(sed_escape "$JNDI_PROVIDER_URL")|g" kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

echo "Step 3: creating the namespace..."
kubectl apply -f kubernetes/namespace.yaml || { echo "ERROR: applying namespace.yaml failed"; exit 1; }

echo "Step 4: creating the secret ${SECRET_NAME}..."
kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" --from-literal=weather-api-key="$WEATHER_API_KEY" --dry-run=client -o yaml | kubectl apply -f - || { echo "ERROR: creating the secret failed"; exit 1; }

echo "Step 5: applying the deployment, the service and the ingress..."
kubectl apply -f kubernetes/deployment.yaml || { echo "ERROR: applying deployment.yaml failed"; exit 1; }
kubectl apply -f kubernetes/service.yaml || { echo "ERROR: applying service.yaml failed"; exit 1; }
kubectl apply -f kubernetes/ingress.yaml || { echo "ERROR: applying ingress.yaml failed"; exit 1; }

echo "Step 6: waiting for the rollout..."
if ! kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s; then
  echo "ERROR: the rollout did not finish."
  echo "Look at the pods:   kubectl describe pods -n ${NAMESPACE}  and  kubectl logs deployment/${APP_NAME} -n ${NAMESPACE}"
  echo "Roll back with:     kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  exit 1
fi

echo "Step 7: the state of the deployment"
kubectl get pods,svc,ingress -n ${NAMESPACE}

ALB_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
if [ -n "$ALB_HOST" ]; then
  echo "Application URL: http://${ALB_HOST}/resorts/"
  echo "Health check:    http://${ALB_HOST}/resorts/health"
else
  echo "The load balancer address is not ready yet. Check later with: kubectl get ingress -n ${NAMESPACE}"
fi

echo "To roll back a bad release: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
echo "Deployment finished."
