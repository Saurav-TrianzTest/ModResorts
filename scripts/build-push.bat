@echo off
setlocal enabledelayedexpansion

echo === ModResortsContainer Build and Push Script ===

set "PROJECT_NAME=ModResortsContainer"
set "IMAGE_NAME=%PROJECT_NAME%"
REM sanitize: lowercase and replace non-alphanumeric with hyphen
for /f "delims=" %%i in ('powershell -Command "$n='%PROJECT_NAME%'.ToLower(); ($n -replace '[^a-z0-9]+','-') -replace '^-+|-+$',''"') do set "IMAGE_NAME=%%i"

echo Select target platform:
echo 1. AWS ECR
echo 2. Docker Hub
set /p PLATFORM_CHOICE="Enter choice (1 or 2): "

if "%PLATFORM_CHOICE%"=="1" (
  set /p AWS_REGION="Enter AWS region: "
  set /p ECR_REPO="Enter ECR repository name: "
  set /p IMAGE_TAG="Enter image tag (or press Enter for latest): "
  if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"
  set "REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com"
  set "FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!"

  echo Logging in to Amazon ECR...
  call aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
  if !ERRORLEVEL! neq 0 (echo ECR login failed & exit /b 1)

  echo Creating ECR repository if it does not exist...
  call aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
  if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository...
    call aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
  )

  echo Building Docker image...
  docker build -f Dockerfile -t "!FULL_IMAGE_NAME!" .
  if !ERRORLEVEL! neq 0 (echo Docker build failed & exit /b 1)

  echo Pushing Docker image...
  docker push "!FULL_IMAGE_NAME!"
  if !ERRORLEVEL! neq 0 (echo Docker push failed & exit /b 1)

  echo Image pushed successfully: !FULL_IMAGE_NAME!
) else if "%PLATFORM_CHOICE%"=="2" (
  set /p DOCKER_USERNAME="Enter Docker Hub username: "
  set /p DOCKER_REPO="Enter Docker Hub repository name: "
  set /p IMAGE_TAG="Enter image tag (or press Enter for latest): "
  if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"
  set "FULL_IMAGE_NAME=!DOCKER_USERNAME!/!DOCKER_REPO!:!IMAGE_TAG!"

  echo Logging in to Docker Hub...
  set /p DOCKER_PASSWORD="Enter Docker Hub password: "
  echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
  if !ERRORLEVEL! neq 0 (echo Docker Hub login failed & exit /b 1)

  echo Building Docker image...
  docker build -f Dockerfile -t "!FULL_IMAGE_NAME!" .
  if !ERRORLEVEL! neq 0 (echo Docker build failed & exit /b 1)

  echo Pushing Docker image...
  docker push "!FULL_IMAGE_NAME!"
  if !ERRORLEVEL! neq 0 (echo Docker push failed & exit /b 1)

  echo Image pushed successfully: !FULL_IMAGE_NAME!
) else (
  echo Invalid choice. Exiting.
  exit /b 1
)

echo === Build and push complete ===
endlocal
