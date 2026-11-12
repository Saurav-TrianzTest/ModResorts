@echo off
setlocal enabledelayedexpansion

REM Build and push script for modresorts to AWS ECR
REM Runs from the repository root, never changes directory

set "PROJECT_NAME=modresorts"
set "IMAGE_NAME=%PROJECT_NAME%"

echo === ModResorts Build and Push ===
echo Project: %PROJECT_NAME%
echo Image: %IMAGE_NAME%
echo.

REM Ask for AWS region
set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
if "!AWS_REGION!"=="" (
    echo AWS region is required.
    exit /b 1
)

REM Ask for ECR registry URL
set /p REGISTRY_URL="Enter ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com): "
if "!REGISTRY_URL!"=="" (
    echo ECR registry URL is required.
    exit /b 1
)

REM Ask for ECR repository name
set /p ECR_REPO="Enter ECR repository name (default: %IMAGE_NAME%): "
if "!ECR_REPO!"=="" (
    set "ECR_REPO=%IMAGE_NAME%"
)

REM Ask for image tag
set /p IMAGE_TAG="Enter image tag (leave empty for 'latest'): "
if "!IMAGE_TAG!"=="" (
    set "IMAGE_TAG=latest"
)

REM Sanitize tag using PowerShell
for /f "delims=" %%i in ('powershell -command "('$IMAGE_TAG' -replace '[^a-z0-9.\-]', '-').Trim('-')"') do set "IMAGE_TAG=%%i"
if "!IMAGE_TAG!"=="" (
    set "IMAGE_TAG=latest"
)

set "FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!"

echo.
echo === Configuration ===
echo AWS Region: !AWS_REGION!
echo Registry: !REGISTRY_URL!
echo Repository: !ECR_REPO!
echo Tag: !IMAGE_TAG!
echo Full Image Name: !FULL_IMAGE_NAME!
echo.

REM Login to ECR
echo === Logging in to ECR ===
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
    echo ECR login failed
    exit /b 1
)
echo ECR login successful.
echo.

REM Create repository if it doesn't exist
echo === Ensuring ECR repository exists ===
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository...
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo Failed to create ECR repository.
        exit /b 1
    )
)
echo Repository '!ECR_REPO!' is ready.
echo.

REM Build the Docker image
echo === Building Docker image ===
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
    echo Docker build failed
    exit /b 1
)
echo Docker image built successfully.
echo.

REM Push the image
echo === Pushing Docker image to ECR ===
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
    echo Docker push failed
    exit /b 1
)
echo Docker image pushed successfully.
echo.

echo === Done ===
echo Image: !FULL_IMAGE_NAME!

endlocal
