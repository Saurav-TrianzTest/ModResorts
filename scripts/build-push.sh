#!/bin/bash
set -e

PROJECT_NAME="ModResorts"

# Sanitize project name: lowercase, replace non-alphanumeric with hyphens, trim leading/trailing hyphens
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=== Build and Push Script for $IMAGE_NAME ==="
echo ""

# Ask for target platform
echo "Select target platform:"
echo "1. AWS ECR"
echo "2. Docker Hub"
read -p "Enter choice (1 or 2): " PLATFORM_CHOICE

if [ "$PLATFORM_CHOICE" = "1" ]; then
  echo ""
  echo "=== AWS ECR ==="
  read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
  read -p "Enter AWS account ID: " AWS_ACCOUNT_ID
  read -p "Enter ECR repository name (default: $IMAGE_NAME): " ECR_REPO
  ECR_REPO=${ECR_REPO:-$IMAGE_NAME}

  REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}"

  read -p "Enter IMAGE_TAG (press Enter for latest): " IMAGE_TAG
  IMAGE_TAG=${IMAGE_TAG:-latest}

  FULL_IMAGE="${FULL_IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to AWS ECR..."
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"

  echo ""
  echo "Creating ECR repository if it does not exist..."
  aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"

  echo ""
  echo "Building Docker image..."
  docker build -f Dockerfile -t "$FULL_IMAGE" .

  echo ""
  echo "Pushing Docker image to ECR..."
  docker push "$FULL_IMAGE"

  echo ""
  echo "=== Build and push complete ==="
  echo "Image: $FULL_IMAGE"

elif [ "$PLATFORM_CHOICE" = "2" ]; then
  echo ""
  echo "=== Docker Hub ==="
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password: " DOCKER_PASSWORD
  echo ""

  read -p "Enter image name (default: $IMAGE_NAME): " DOCKER_IMAGE_NAME
  DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-$IMAGE_NAME}

  read -p "Enter IMAGE_TAG (press Enter for latest): " IMAGE_TAG
  IMAGE_TAG=${IMAGE_TAG:-latest}

  FULL_IMAGE="${DOCKER_USERNAME}/${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Docker Hub..."
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin

  echo ""
  echo "Building Docker image..."
  docker build -f Dockerfile -t "$FULL_IMAGE" .

  echo ""
  echo "Pushing Docker image to Docker Hub..."
  docker push "$FULL_IMAGE"

  echo ""
  echo "=== Build and push complete ==="
  echo "Image: $FULL_IMAGE"

else
  echo "Invalid choice. Exiting."
  exit 1
fi
