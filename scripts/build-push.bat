@echo off
setlocal enabledelayedexpansion

REM Project name - pre-sanitized (lowercase, alphanumeric only)
set IMAGE_NAME=modresorts

echo === ModResorts Container Build and Push ===
echo.

set /p AWS_REGION="Enter AWS region (e.g., us-east-1) "
set /p ECR_REPO="Enter ECR repository name (default !IMAGE_NAME!) "
if "!ECR_REPO!"=="" set ECR_REPO=!IMAGE_NAME!
set /p IMAGE_TAG="Enter image tag (default latest) "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
set /p AWS_ACCOUNT_ID="Enter AWS account ID "

set REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com
REM Build full image name using PowerShell to avoid colon in set command
call powershell -Command "Write-Output ('!REGISTRY_URL!/!ECR_REPO!' + [char]58 + '!IMAGE_TAG!')" > tmp_colon.txt
set /p FULL_IMAGE_NAME=<tmp_colon.txt
del tmp_colon.txt

echo.
echo === Build Configuration ===
echo   Image Name - !IMAGE_NAME!
echo   Registry   - !REGISTRY_URL!
echo   Repository - !ECR_REPO!
echo   Tag        - !IMAGE_TAG!
echo   Full       - !FULL_IMAGE_NAME!
echo.

echo === Logging in to Amazon ECR ===
call aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (echo ECR login failed ^& exit /b 1)

echo === Checking ECR repository ===
call aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
  echo Creating ECR repository...
  call aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
  if !ERRORLEVEL! neq 0 (echo Failed to create ECR repository ^& exit /b 1)
)

echo === Building Docker image ===
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (echo Docker build failed ^& exit /b 1)

echo === Pushing Docker image to ECR ===
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (echo Docker push failed ^& exit /b 1)

echo.
echo === Build and push complete ===
echo   Image - !FULL_IMAGE_NAME!

endlocal
