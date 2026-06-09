@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: deploy-image.bat - Deploy ModResorts to AWS EKS (Windows)
:: Usage: scripts\deploy-image.bat
:: Run from repository root directory
:: Prerequisites: aws-cli, kubectl
:: ============================================================

set APP_NAME=modresorts
set NAMESPACE=modresorts
set K8S_DIR=kubernetes

echo ============================================
echo   ModResorts - AWS EKS Deployment Script
echo ============================================
echo.

:: ---- Collect deployment inputs ----
set /p AWS_REGION="Enter AWS Region (e.g. us-east-1): "
if "!AWS_REGION!"=="" (
  echo ERROR: AWS Region is required.
  exit /b 1
)

set /p CLUSTER_NAME="Enter EKS Cluster Name: "
if "!CLUSTER_NAME!"=="" (
  echo ERROR: EKS Cluster Name is required.
  exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest): "
if "!IMAGE_URI!"=="" (
  echo ERROR: Docker image URI is required.
  exit /b 1
)

echo.
echo ---- Optional Application Environment Variables ----
echo (Press Enter to skip any variable)
echo.

set /p WEATHER_API_KEY_VAL="Enter value for WEATHER_API_KEY (Weather Underground API key): "
set /p SERVER_DISPLAY_NAME_VAL="Enter value for SERVER_DISPLAY_NAME (server display name): "
set /p SERVER_FULL_NAME_VAL="Enter value for SERVER_FULL_NAME (server full name): "

if "!SERVER_DISPLAY_NAME_VAL!"=="" set SERVER_DISPLAY_NAME_VAL=modresorts-container
if "!SERVER_FULL_NAME_VAL!"=="" set SERVER_FULL_NAME_VAL=modresorts-container-1

echo.
echo ---- Configuring kubectl for EKS ----
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to configure kubectl. Check your AWS credentials and cluster name.
  exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
  echo ERROR: Cannot connect to EKS cluster.
  exit /b 1
)

echo.
echo ---- Updating Kubernetes manifests ----

:: Replace placeholders using PowerShell
powershell -Command "(Get-Content '!K8S_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '!K8S_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to update IMAGE_URI in deployment.yaml
  exit /b 1
)

powershell -Command "(Get-Content '!K8S_DIR!\deployment.yaml') -replace '{{WEATHER_API_KEY}}', '!WEATHER_API_KEY_VAL!' | Set-Content '!K8S_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!K8S_DIR!\deployment.yaml') -replace '{{SERVER_DISPLAY_NAME}}', '!SERVER_DISPLAY_NAME_VAL!' | Set-Content '!K8S_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!K8S_DIR!\deployment.yaml') -replace '{{SERVER_FULL_NAME}}', '!SERVER_FULL_NAME_VAL!' | Set-Content '!K8S_DIR!\deployment.yaml'"

echo.
echo ---- Applying Kubernetes manifests ----

echo Applying namespace...
kubectl apply -f !K8S_DIR!\namespace.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply namespace.
  exit /b 1
)

echo Applying deployment...
kubectl apply -f !K8S_DIR!\deployment.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply deployment.
  exit /b 1
)

echo Applying service...
kubectl apply -f !K8S_DIR!\service.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply service.
  exit /b 1
)

echo Applying ingress...
kubectl apply -f !K8S_DIR!\ingress.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply ingress.
  exit /b 1
)

echo.
echo ---- Waiting for deployment rollout ----
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
  echo ERROR: Deployment rollout failed or timed out.
  echo To rollback, run: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
  exit /b 1
)

echo.
echo ---- Verifying deployed resources ----
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo ---- Application Access ----
echo Application URL: http://modresorts.example.com/resorts/
echo Health Check:    http://modresorts.example.com/resorts/health
echo.
echo Note: Retrieve the actual ALB hostname with:
echo   kubectl get ingress !APP_NAME!-ingress -n !NAMESPACE! -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"

echo.
echo ============================================
echo   SUCCESS: ModResorts deployed to EKS!
echo ============================================
echo.
echo Rollback command (if needed):
echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!

endlocal
