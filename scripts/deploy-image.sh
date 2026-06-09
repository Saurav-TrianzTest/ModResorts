#!/bin/bash
set -e
set -o pipefail

# ============================================================
# deploy-image.sh - Deploy ModResorts to AWS EKS
# Usage: ./scripts/deploy-image.sh
# Run from repository root directory
# Prerequisites: aws-cli, kubectl
# ============================================================

APP_NAME="modresorts"
NAMESPACE="modresorts"
K8S_DIR="kubernetes"

echo "============================================"
echo "  ModResorts - AWS EKS Deployment Script"
echo "============================================"
echo ""

# ---- Collect deployment inputs ----
read -rp "Enter AWS Region (e.g. us-east-1): " AWS_REGION
if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS Region is required."
  exit 1
fi

read -rp "Enter EKS Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: EKS Cluster Name is required."
  exit 1
fi

read -rp "Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

echo ""
echo "---- Optional Application Environment Variables ----"
echo "(Press Enter to skip any variable)"
echo ""

read -rp "Enter value for WEATHER_API_KEY (Weather Underground API key): " WEATHER_API_KEY_VAL
read -rp "Enter value for SERVER_DISPLAY_NAME (server display name): " SERVER_DISPLAY_NAME_VAL
read -rp "Enter value for SERVER_FULL_NAME (server full name): " SERVER_FULL_NAME_VAL

echo ""
echo "---- Configuring kubectl for EKS ----"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to configure kubectl. Check your AWS credentials and cluster name."
  exit 1
fi

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to EKS cluster."; exit 1; }

echo ""
echo "---- Updating Kubernetes manifests ----"

# Replace IMAGE_URI placeholder
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" "${K8S_DIR}/deployment.yaml"

# Replace environment variable placeholders
if [ -n "$WEATHER_API_KEY_VAL" ]; then
  sed -i "s|{{WEATHER_API_KEY}}|${WEATHER_API_KEY_VAL}|g" "${K8S_DIR}/deployment.yaml"
else
  sed -i "s|{{WEATHER_API_KEY}}||g" "${K8S_DIR}/deployment.yaml"
fi

if [ -n "$SERVER_DISPLAY_NAME_VAL" ]; then
  sed -i "s|{{SERVER_DISPLAY_NAME}}|${SERVER_DISPLAY_NAME_VAL}|g" "${K8S_DIR}/deployment.yaml"
else
  sed -i "s|{{SERVER_DISPLAY_NAME}}|modresorts-container|g" "${K8S_DIR}/deployment.yaml"
fi

if [ -n "$SERVER_FULL_NAME_VAL" ]; then
  sed -i "s|{{SERVER_FULL_NAME}}|${SERVER_FULL_NAME_VAL}|g" "${K8S_DIR}/deployment.yaml"
else
  sed -i "s|{{SERVER_FULL_NAME}}|modresorts-container-1|g" "${K8S_DIR}/deployment.yaml"
fi

echo ""
echo "---- Applying Kubernetes manifests ----"

echo "Applying namespace..."
kubectl apply -f "${K8S_DIR}/namespace.yaml"

echo "Applying deployment..."
kubectl apply -f "${K8S_DIR}/deployment.yaml"

echo "Applying service..."
kubectl apply -f "${K8S_DIR}/service.yaml"

echo "Applying ingress..."
kubectl apply -f "${K8S_DIR}/ingress.yaml"

echo ""
echo "---- Waiting for deployment rollout ----"
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed or timed out."
  echo "To rollback, run: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  exit 1
fi

echo ""
echo "---- Verifying deployed resources ----"
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo ""
echo "---- Application Access ----"
INGRESS_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "modresorts.example.com")
echo "Application URL: http://${INGRESS_HOST}/resorts/"
echo "Health Check:    http://${INGRESS_HOST}/resorts/health"
echo ""
echo "Note: If using AWS ALB, retrieve the actual hostname with:"
echo "  kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"

echo ""
echo "============================================"
echo "  SUCCESS: ModResorts deployed to EKS!"
echo "============================================"
echo ""
echo "Rollback command (if needed):"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
