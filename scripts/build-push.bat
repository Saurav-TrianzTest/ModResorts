@echo off & setlocal enabledelayedexpansion
rem Builds the ContainerSanity image and pushes it to AWS ECR or Docker Hub.
rem Run from the repository root with scripts\build-push.bat

set "PROJECT_NAME=ContainerSanity"
set "IMAGE_NAME=containersanity"

where docker >nul 2>&1
if !ERRORLEVEL! neq 0 (
  echo ERROR - docker is not installed
  exit /b 1
)

echo === Build and push !IMAGE_NAME! ===
echo Select the registry
echo   1. AWS ECR
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter 1 or 2: "

if "!REGISTRY_CHOICE!"=="1" goto ecr
if "!REGISTRY_CHOICE!"=="2" goto dockerhub
echo ERROR - invalid choice, enter 1 or 2
exit /b 1

:ecr
where aws >nul 2>&1
if !ERRORLEVEL! neq 0 (
  echo ERROR - the AWS CLI is not installed
  exit /b 1
)
set /p AWS_REGION="Enter the AWS region (for example us-east-1): "
set /p AWS_ACCOUNT_ID="Enter the AWS account ID: "
set "ECR_REPO="
set /p ECR_REPO="Enter the ECR repository name (press Enter for !IMAGE_NAME!): "
if "!ECR_REPO!"=="" set "ECR_REPO=!IMAGE_NAME!"
set "REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com"
set "REPO_PATH=!ECR_REPO!"
goto tag

:dockerhub
set /p DOCKER_USERNAME="Enter the Docker Hub username: "
set /p DOCKER_PASSWORD="Enter the Docker Hub password or access token: "
set "DOCKER_REPO="
set /p DOCKER_REPO="Enter the repository name (press Enter for !IMAGE_NAME!): "
if "!DOCKER_REPO!"=="" set "DOCKER_REPO=!IMAGE_NAME!"
set "REGISTRY_URL=docker.io"
set "REPO_PATH=!DOCKER_USERNAME!/!DOCKER_REPO!"
goto tag

:tag
set "IMAGE_TAG="
set /p IMAGE_TAG="Enter the image tag (press Enter for latest): "
if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"
set "TAG_FILE=%TEMP%\containersanity-tag.txt"
powershell -NoProfile -Command "('!IMAGE_TAG!').ToLower() -replace '[^a-z0-9._-]+','-' -replace '^-+|-+$',''" > "!TAG_FILE!"
set "IMAGE_TAG=latest"
set /p IMAGE_TAG=<"!TAG_FILE!"
del "!TAG_FILE!" >nul 2>&1
if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"

set "FULL_IMAGE_NAME="
powershell -NoProfile -Command "'!REGISTRY_URL!/!REPO_PATH!' + [char]58 + '!IMAGE_TAG!'" > "!TAG_FILE!"
set /p FULL_IMAGE_NAME=<"!TAG_FILE!"
del "!TAG_FILE!" >nul 2>&1
if "!FULL_IMAGE_NAME!"=="" (
  echo ERROR - could not build the image name
  exit /b 1
)
echo Image name is !FULL_IMAGE_NAME!

echo Step 1 of 3 - building the image
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
  echo Docker build failed
  exit /b 1
)

echo Step 2 of 3 - logging in to the registry
if "!REGISTRY_CHOICE!"=="2" goto login_hub
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
  echo ECR login failed
  exit /b 1
)
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
  echo Creating ECR repository...
  aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
  if !ERRORLEVEL! neq 0 (
    echo Creating the ECR repository failed
    exit /b 1
  )
)
goto push

:login_hub
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
  echo Docker Hub login failed
  exit /b 1
)

:push
echo Step 3 of 3 - pushing the image
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
  echo Docker push failed
  exit /b 1
)

echo Done. Pushed !FULL_IMAGE_NAME!
echo Use this image URI with scripts\deploy-image.bat
endlocal
