@echo off
setlocal enabledelayedexpansion

echo === ModResortsContainer Deployment Script (AWS EKS) ===

set "PROJECT_NAME=ModResortsContainer"
for /f "delims=" %%i in ('powershell -Command "$n='%PROJECT_NAME%'.ToLower(); ($n -replace '[^a-z0-9]+','-') -replace '^-+|-+$',''"') do set "NAME=%%i"

set /p AWS_REGION="Enter AWS region: "
set /p CLUSTER_NAME="Enter EKS cluster name: "
set /p IMAGE_URI="Enter full image URI (registry/repo:tag): "

set /p WEATHER_API_KEY_VALUE="Enter value for WEATHER_API_KEY (or press Enter to skip): "

echo Configuring kubectl for EKS cluster...
call aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (echo Failed to configure kubectl & exit /b 1)

echo Checking cluster connectivity...
call kubectl cluster-info
if !ERRORLEVEL! neq 0 (echo Cluster connectivity check failed & exit /b 1)

echo Applying namespace...
call kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (echo Namespace application failed & exit /b 1)

echo Creating Kubernetes Secret...
set "SECRET_ARGS="
if not "!WEATHER_API_KEY_VALUE!"=="" (
  set "SECRET_ARGS=--from-literal=weather-api-key=!WEATHER_API_KEY_VALUE!"
)

if not "!SECRET_ARGS!"=="" (
  call kubectl create secret generic !NAME!-secrets -n !NAME! !SECRET_ARGS! --dry-run=client -o yaml | kubectl apply -f -
  if !ERRORLEVEL! neq 0 (echo Secret creation failed & exit /b 1)
)

echo Deploying application...
copy kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul
call powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Out-File -encoding ASCII kubernetes\deployment.yaml"
call powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{NAME}}', '!NAME!' | Out-File -encoding ASCII kubernetes\deployment.yaml"

call kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (echo Deployment failed & exit /b 1)
del kubernetes\deployment.yaml.bak

echo Applying service...
call kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (echo Service application failed & exit /b 1)

echo Applying ingress...
call kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (echo Ingress application failed & exit /b 1)

echo Waiting for deployment rollout...
call kubectl rollout status deployment\!NAME! -n !NAME!
if !ERRORLEVEL! neq 0 (echo Rollout failed & exit /b 1)

echo Showing pods, services, and ingress...
call kubectl get pods,svc,ingress -n !NAME!

echo Application URL:
call kubectl get ingress -n !NAME! -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}"

echo.
echo === Deployment complete ===
echo If deployment fails, rollback with:
echo   kubectl rollout undo deployment\!NAME! -n !NAME!

endlocal
