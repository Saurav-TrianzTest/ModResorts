#!/bin/bash
set -e

PROJECT_NAME="ModResortsConatinr"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=== Build and Push for $IMAGE_NAME ==="

# Ask for the target platform
echo "Choose target platform:"
echo "  1. AWS ECR"
echo "  2. Docker Hub"
read -p "Enter choice (1 or 2): " PLATFORM_CHOICE

if [ "$PLATFORM_CHOICE" = "1" ]; then
  # AWS ECR
  read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
  read -p "Enter AWS account ID: " AWS_ACCOUNT_ID
  REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  ECR_REPO="$IMAGE_NAME"
  read -p "Enter IMAGE_TAG (or press Enter for latest): " IMAGE_TAG
  if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG="latest"
  fi
  FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

  echo "=== Logging in to AWS ECR ==="
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"

  echo "=== Creating ECR repository if needed ==="
  aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"

  echo "=== Building Docker image ==="
  docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .

  echo "=== Pushing Docker image ==="
  docker push "$FULL_IMAGE_NAME"

  echo "=== Done ==="
  echo "Image pushed to: $FULL_IMAGE_NAME"

elif [ "$PLATFORM_CHOICE" = "2" ]; then
  # Docker Hub
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password: " DOCKER_PASSWORD
  echo ""
  read -p "Enter IMAGE_TAG (or press Enter for latest): " IMAGE_TAG
  if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG="latest"
  fi
  FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo "=== Logging in to Docker Hub ==="
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin

  echo "=== Building Docker image ==="
  docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .

  echo "=== Pushing Docker image ==="
  docker push "$FULL_IMAGE_NAME"

  echo "=== Done ==="
  echo "Image pushed to: $FULL_IMAGE_NAME"

else
  echo "Invalid choice. Exiting."
  exit 1
fi
