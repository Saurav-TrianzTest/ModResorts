#!/bin/bash
set -e

# Build and push script for modresorts to AWS ECR
# Runs from the repository root, never changes directory

PROJECT_NAME="modresorts"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=== ModResorts Build and Push ==="
echo "Project: $PROJECT_NAME"
echo "Image: $IMAGE_NAME"
echo ""

# Ask for AWS region
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
if [ -z "$AWS_REGION" ]; then
  echo "AWS region is required."
  exit 1
fi

# Ask for ECR registry URL
read -p "Enter ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com): " REGISTRY_URL
if [ -z "$REGISTRY_URL" ]; then
  echo "ECR registry URL is required."
  exit 1
fi

# Ask for ECR repository name
read -p "Enter ECR repository name (default: $IMAGE_NAME): " ECR_REPO
if [ -z "$ECR_REPO" ]; then
  ECR_REPO="$IMAGE_NAME"
fi

# Ask for image tag
read -p "Enter image tag (leave empty for 'latest'): " IMAGE_TAG
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

# Sanitize tag
IMAGE_TAG=$(echo "$IMAGE_TAG" | tr -cs 'a-z0-9.-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

echo ""
echo "=== Configuration ==="
echo "AWS Region: $AWS_REGION"
echo "Registry: $REGISTRY_URL"
echo "Repository: $ECR_REPO"
echo "Tag: $IMAGE_TAG"
echo "Full Image Name: $FULL_IMAGE_NAME"
echo ""

# Login to ECR
echo "=== Logging in to ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
echo "ECR login successful."
echo ""

# Create repository if it doesn't exist
echo "=== Ensuring ECR repository exists ==="
aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
echo "Repository '$ECR_REPO' is ready."
echo ""

# Build the Docker image
echo "=== Building Docker image ==="
docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .
echo "Docker image built successfully."
echo ""

# Push the image
echo "=== Pushing Docker image to ECR ==="
docker push "$FULL_IMAGE_NAME"
echo "Docker image pushed successfully."
echo ""

echo "=== Done ==="
echo "Image: $FULL_IMAGE_NAME"
