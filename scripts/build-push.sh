#!/bin/bash
set -e

echo "=== ModResortsContainer Build and Push Script ==="

# Project name
PROJECT_NAME="ModResortsContainer"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

# Ask for target platform
echo "Select target platform:"
echo "1. AWS ECR"
echo "2. Docker Hub"
read -p "Enter choice (1 or 2): " PLATFORM_CHOICE

if [ "$PLATFORM_CHOICE" = "1" ]; then
  # AWS ECR
  read -p "Enter AWS region: " AWS_REGION
  read -p "Enter ECR repository name: " ECR_REPO
  read -p "Enter image tag (or press Enter for latest): " IMAGE_TAG

  if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG="latest"
  fi

  REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

  echo "Logging in to Amazon ECR..."
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"

  echo "Creating ECR repository if it does not exist..."
  aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"

  echo "Building Docker image..."
  docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .

  echo "Pushing Docker image..."
  docker push "$FULL_IMAGE_NAME"

  echo "Image pushed successfully: $FULL_IMAGE_NAME"

elif [ "$PLATFORM_CHOICE" = "2" ]; then
  # Docker Hub
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -p "Enter Docker Hub repository name: " DOCKER_REPO
  read -p "Enter image tag (or press Enter for latest): " IMAGE_TAG

  if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG="latest"
  fi

  FULL_IMAGE_NAME="${DOCKER_USERNAME}/${DOCKER_REPO}:${IMAGE_TAG}"

  echo "Logging in to Docker Hub..."
  DOCKER_PASSWORD=""
  read -s -p "Enter Docker Hub password: " DOCKER_PASSWORD
  echo ""
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin

  echo "Building Docker image..."
  docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .

  echo "Pushing Docker image..."
  docker push "$FULL_IMAGE_NAME"

  echo "Image pushed successfully: $FULL_IMAGE_NAME"

else
  echo "Invalid choice. Exiting."
  exit 1
fi

echo "=== Build and push complete ==="
