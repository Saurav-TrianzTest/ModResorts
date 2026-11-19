#!/bin/bash
set -e

# Project name
PROJECT_NAME="ModResorts"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

# Ask for AWS region
echo "=== ModResorts Container Build & Push ==="
echo ""
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION

# Ask for ECR repository name
read -p "Enter ECR repository name (default: $IMAGE_NAME): " ECR_REPO
if [ -z "$ECR_REPO" ]; then
  ECR_REPO="$IMAGE_NAME"
fi

# Ask for image tag
read -p "Enter image tag (default: latest): " IMAGE_TAG
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

# AWS account ID
read -p "Enter AWS account ID: " AWS_ACCOUNT_ID

REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

echo ""
echo "=== Build Configuration ==="
echo "  Image Name: $IMAGE_NAME"
echo "  Registry:   $REGISTRY_URL"
echo "  Repository: $ECR_REPO"
echo "  Tag:        $IMAGE_TAG"
echo "  Full:       $FULL_IMAGE_NAME"
echo ""

# Login to ECR
echo "=== Logging in to Amazon ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"

# Create repository if it doesn't exist
echo "=== Checking ECR repository ==="
aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"

# Build the image
echo "=== Building Docker image ==="
docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .

# Push the image
echo "=== Pushing Docker image to ECR ==="
docker push "$FULL_IMAGE_NAME"

echo ""
echo "=== Build and push complete ==="
echo "  Image: $FULL_IMAGE_NAME"
