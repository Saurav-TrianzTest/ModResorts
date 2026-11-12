@echo off
setlocal enabledelayedexpansion

set "PROJECT_NAME=ModResortsConatinr"
:: Sanitize image name: lowercase, replace non-alphanumeric with hyphen, trim leading/trailing hyphens
set "IMAGE_NAME=%PROJECT_NAME%"
:: Convert to lowercase
for /f "usebackq del" %%a in (`powershell -Command "$env:PROJECT_NAME.ToLower()"`) do set "IMAGE_NAME=%%a"
:: Replace non-alphanumeric with hyphen
set "IMAGE_NAME=!IMAGE_NAME: =!"
for /f "usebackq del" %%a in (`powershell -Command "('$env:IMAGE_NAME' -replace '[^a-z0-9]', '-') -replace '^-+|-+$', ''"`) do set "IMAGE_NAME=%%a"

echo === Build and Push for !IMAGE_NAME! ===

echo Choose target platform:
echo   1. AWS ECR
echo   2. Docker Hub
set /p PLATFORM_CHOICE="Enter choice (1 or 2): "

if "!PLATFORM_CHOICE!"=="1" (
  set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
  set /p AWS_ACCOUNT_ID="Enter AWS account ID: "
  set "REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com"
  set "ECR_REPO=!IMAGE_NAME!"
  set /p IMAGE_TAG="Enter IMAGE_TAG (or press Enter for latest): "
  if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"
  set "FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!"
  for /f "usebackq del" %%a in (`powershell -Command "'!FULL_IMAGE_NAME!:!IMAGE_TAG!'"`) do set "FULL_IMAGE_NAME=%%a"

  echo === Logging in to AWS ECR ===
  for /f "usebackq del" %%a in (`aws ecr get-login-password --region !AWS_REGION!`) do set "AWS_ECR_PASSWORD=%%a"
  echo !AWS_ECR_PASSWORD! | docker login --username AWS --password-stdin !REGISTRY_URL!
  if !ERRORLEVEL! neq 0 (
    echo ECR login failed
    exit /b 1
  )

  echo === Creating ECR repository if needed ===
  aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
  if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository...
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
      echo Failed to create ECR repository
      exit /b 1
    )
  )

  echo === Building Docker image ===
  docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
  if !ERRORLEVEL! neq 0 (
    echo Docker build failed
    exit /b 1
  )

  echo === Pushing Docker image ===
  docker push !FULL_IMAGE_NAME!
  if !ERRORLEVEL! neq 0 (
    echo Docker push failed
    exit /b 1
  )

  echo === Done ===
  echo Image pushed to: !FULL_IMAGE_NAME!
) else if "!PLATFORM_CHOICE!"=="2" (
  set /p DOCKER_USERNAME="Enter Docker Hub username: "
  set /p DOCKER_PASSWORD="Enter Docker Hub password: "
  set /p IMAGE_TAG="Enter IMAGE_TAG (or press Enter for latest): "
  if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"
  set "FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!"
  for /f "usebackq del" %%a in (`powershell -Command "'!FULL_IMAGE_NAME!:!IMAGE_TAG!'"`) do set "FULL_IMAGE_NAME=%%a"

  echo === Logging in to Docker Hub ===
  echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
  if !ERRORLEVEL! neq 0 (
    echo Docker Hub login failed
    exit /b 1
  )

  echo === Building Docker image ===
  docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
  if !ERRORLEVEL! neq 0 (
    echo Docker build failed
    exit /b 1
  )

  echo === Pushing Docker image ===
  docker push !FULL_IMAGE_NAME!
  if !ERRORLEVEL! neq 0 (
    echo Docker push failed
    exit /b 1
  )

  echo === Done ===
  echo Image pushed to: !FULL_IMAGE_NAME!
) else (
  echo Invalid choice. Exiting.
  exit /b 1
)
