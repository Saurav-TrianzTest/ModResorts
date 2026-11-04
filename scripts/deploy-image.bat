@echo off
setlocal enabledelayedexpansion

set PROJECT_NAME=ModResorts
for /f "delims=" %%i in ('cmd /c "echo %PROJECT_NAME% | powershell -Command "($input | ForEach-Object { $_.ToString().ToLower() -replace '[^a-z0-9]', '-' -replace '^-+|-+$', '' })"') do set IMAGE_NAME=%%i
set NAMESPACE=!IMAGE_NAME!

echo === Deploy Image to AWS EKS ===
echo.

set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
set /p CLUSTER_NAME="Enter EKS cluster name: "
set /p IMAGE_URI="Enter full image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:2.0.0): "

echo.
echo Configuring kubectl for EKS cluster...
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (echo Failed to configure kubectl & exit /b 1)

echo.
echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (echo Cluster connectivity check failed & exit /b 1)

echo.
echo === Creating Kubernetes Secret ===
set /p WEATHER_API_KEY_VAL="Enter WEATHER_API_KEY (or press Enter to skip): "

set SECRET_ARGS=
if not "!WEATHER_API_KEY_VAL!"=="" set SECRET_ARGS=--from-literal=weather-api-key=!WEATHER_API_KEY_VAL!

if not "!SECRET_ARGS!"=="" (
    echo Creating secret !NAMESPACE!-secrets...
    kubectl create secret generic "!NAMESPACE!-secrets" -n "!NAMESPACE!" !SECRET_ARGS! --dry-run=client -o yaml | kubectl apply -f -
    if !ERRORLEVEL! neq 0 (echo Secret creation failed & exit /b 1)
) else (
    echo No credentials provided, skipping secret creation.
)

set /p JNDI_FACTORY_VAL="Enter JNDI_FACTORY (or press Enter to skip): "
set /p JNDI_PROVIDER_URL_VAL="Enter JNDI_PROVIDER_URL (or press Enter to skip): "

echo.
echo === Applying Kubernetes manifests ===

kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (echo Namespace creation failed & exit /b 1)

REM Replace placeholders in deployment.yaml
powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Out-File -encoding ASCII kubernetes\deployment.yaml.tmp"
powershell -Command "(gc kubernetes\deployment.yaml.tmp) -replace '{{JNDI_FACTORY}}', '!JNDI_FACTORY_VAL!' | Out-File -encoding ASCII kubernetes\deployment.yaml.tmp2"
powershell -Command "(gc kubernetes\deployment.yaml.tmp2) -replace '{{JNDI_PROVIDER_URL}}', '!JNDI_PROVIDER_URL_VAL!' | Out-File -encoding ASCII kubernetes\deployment.yaml.tmp"
move /Y kubernetes\deployment.yaml.tmp kubernetes\deployment.yaml >nul
del kubernetes\deployment.yaml.tmp2

kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (echo Deployment creation failed & exit /b 1)

kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (echo Service creation failed & exit /b 1)

kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (echo Ingress creation failed & exit /b 1)

echo.
echo === Waiting for deployment rollout ===
kubectl rollout status deployment/!NAMESPACE! -n "!NAMESPACE!"
if !ERRORLEVEL! neq 0 (echo Rollout failed & exit /b 1)

echo.
echo === Deployment status ===
kubectl get pods,svc,ingress -n "!NAMESPACE!"

echo.
echo === Deployment complete ===
echo.
echo If the deployment fails, you can rollback with:
echo   kubectl rollout undo deployment/!NAMESPACE! -n !NAMESPACE!

endlocal
