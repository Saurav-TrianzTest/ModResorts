@echo off
setlocal enabledelayedexpansion

set "IMAGE_NAME=modresortsconatinr"

echo === Deploy !IMAGE_NAME! to AWS EKS ===

set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
set /p CLUSTER_NAME="Enter EKS cluster name: "
set /p IMAGE_URI="Enter IMAGE_URI (full path with registry and tag): "

set /p VAR_JAVA_NAMING_FACTORY_INITIAL="Enter value for JAVA_NAMING_FACTORY_INITIAL (or press Enter to skip): "
set /p VAR_JAVA_NAMING_PROVIDER_URL="Enter value for JAVA_NAMING_PROVIDER_URL (or press Enter to skip): "
set /p VAR_DATASOURCE_JNDI="Enter value for DATASOURCE_JNDI (or press Enter to skip): "

set /p VAR_WEATHER_API_KEY="Enter WEATHER_API_KEY (or press Enter to skip): "

echo === Configuring kubectl for EKS cluster ===
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
  echo Failed to configure kubectl
  exit /b 1
)

echo === Checking cluster connectivity ===
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
  echo Cluster connectivity check failed
  exit /b 1
)

echo === Applying namespace ===
kubectl apply -f kubernetes/namespace.yaml
if !ERRORLEVEL! neq 0 (
  echo Failed to apply namespace
  exit /b 1
)

echo === Creating Kubernetes Secret ===
set "SECRET_ARGS="
if not "!VAR_WEATHER_API_KEY!"=="" (
  set "SECRET_ARGS=--from-literal=weather-api-key=!VAR_WEATHER_API_KEY!"
)

if not "!SECRET_ARGS!"=="" (
  kubectl create secret generic !IMAGE_NAME!-secrets -n !IMAGE_NAME! !SECRET_ARGS! --dry-run=client -o yaml | kubectl apply -f -
  if !ERRORLEVEL! neq 0 (
    echo Failed to create secret
    exit /b 1
  )
)

echo === Deploying application ===
:: Replace placeholders in deployment.yaml
if exist kubernetes\deployment.yaml.bak del kubernetes\deployment.yaml.bak
copy kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul

:: Use PowerShell for sed-like replacement
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{JAVA_NAMING_FACTORY_INITIAL}}', '!VAR_JAVA_NAMING_FACTORY_INITIAL!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{JAVA_NAMING_PROVIDER_URL}}', '!VAR_JAVA_NAMING_PROVIDER_URL!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{DATASOURCE_JNDI}}', '!VAR_DATASOURCE_JNDI!' | Set-Content kubernetes\deployment.yaml"

del kubernetes\deployment.yaml.bak

kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (
  echo Failed to apply deployment
  exit /b 1
)

kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (
  echo Failed to apply service
  exit /b 1
)

kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (
  echo Failed to apply ingress
  exit /b 1
)

echo === Waiting for deployment to be ready ===
kubectl rollout status deployment/!IMAGE_NAME! -n !IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
  echo Deployment rollout failed
  exit /b 1
)

echo === Deployment status ===
kubectl get pods,svc,ingress -n !IMAGE_NAME!

echo === Application URL ===
kubectl get ingress !IMAGE_NAME!-ingress -n !IMAGE_NAME! -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"

echo.
echo === Deployment complete ===
echo If something went wrong, rollback with:
echo   kubectl rollout undo deployment/!IMAGE_NAME! -n !IMAGE_NAME!
