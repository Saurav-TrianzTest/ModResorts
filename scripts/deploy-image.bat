@echo off
setlocal enabledelayedexpansion

set APP_NAME=modresorts
set NAMESPACE=modresorts

echo ============================================
echo   ModResorts - Deploy to AWS EKS
echo ============================================
echo.

REM Prompt for AWS region
set /p AWS_REGION="Enter AWS Region (e.g. us-east-1): "
if "!AWS_REGION!"=="" (
    echo ERROR: AWS Region is required.
    exit /b 1
)

REM Prompt for EKS cluster name
set /p CLUSTER_NAME="Enter EKS Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: EKS Cluster Name is required.
    exit /b 1
)

REM Prompt for Docker image URI
set /p IMAGE_URI="Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo --- Optional Application Environment Variables ---
echo (Press Enter to skip any variable)
echo.

set /p WEATHER_API_KEY_VAL="Enter WEATHER_API_KEY value (or press Enter to skip): "
set /p SERVER_DISPLAY_NAME_VAL="Enter SERVER_DISPLAY_NAME value (or press Enter to skip, default: modresorts-server): "
set /p SERVER_FULL_NAME_VAL="Enter SERVER_FULL_NAME value (or press Enter to skip, default: modresorts-server/default): "
set /p JNDI_PROVIDER_URL_VAL="Enter JNDI_PROVIDER_URL value (or press Enter to skip): "
set /p DB_URL_VAL="Enter DB_URL value (or press Enter to skip): "
set /p DB_USERNAME_VAL="Enter DB_USERNAME value (or press Enter to skip): "
set /p DB_PASSWORD_VAL="Enter DB_PASSWORD value (or press Enter to skip): "

if "!SERVER_DISPLAY_NAME_VAL!"=="" set SERVER_DISPLAY_NAME_VAL=modresorts-server
if "!SERVER_FULL_NAME_VAL!"=="" set SERVER_FULL_NAME_VAL=modresorts-server/default

echo.
echo Configuring kubectl for EKS cluster: !CLUSTER_NAME! in !AWS_REGION! ...
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl for EKS cluster.
    exit /b 1
)

echo.
echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to Kubernetes cluster.
    exit /b 1
)

echo.
echo Copying manifests to temp directory...
if exist "%TEMP%\modresorts-k8s-deploy" rmdir /s /q "%TEMP%\modresorts-k8s-deploy"
xcopy /s /e /i /q "..\kubernetes" "%TEMP%\modresorts-k8s-deploy"

echo Updating Kubernetes manifests with deployment values...
powershell -Command "(Get-Content '%TEMP%\modresorts-k8s-deploy\deployment.yaml') -replace '{{IMAGE_URI}}','!IMAGE_URI!' -replace '{{WEATHER_API_KEY}}','!WEATHER_API_KEY_VAL!' -replace '{{SERVER_DISPLAY_NAME}}','!SERVER_DISPLAY_NAME_VAL!' -replace '{{SERVER_FULL_NAME}}','!SERVER_FULL_NAME_VAL!' -replace '{{JNDI_PROVIDER_URL}}','!JNDI_PROVIDER_URL_VAL!' -replace '{{DB_URL}}','!DB_URL_VAL!' -replace '{{DB_USERNAME}}','!DB_USERNAME_VAL!' -replace '{{DB_PASSWORD}}','!DB_PASSWORD_VAL!' | Set-Content '%TEMP%\modresorts-k8s-deploy\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to update deployment manifest.
    exit /b 1
)

echo.
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f "%TEMP%\modresorts-k8s-deploy\namespace.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply namespace. & exit /b 1 )

echo   [2/4] Applying deployment...
kubectl apply -f "%TEMP%\modresorts-k8s-deploy\deployment.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply deployment. & exit /b 1 )

echo   [3/4] Applying service...
kubectl apply -f "%TEMP%\modresorts-k8s-deploy\service.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply service. & exit /b 1 )

echo   [4/4] Applying ingress...
kubectl apply -f "%TEMP%\modresorts-k8s-deploy\ingress.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply ingress. & exit /b 1 )

echo.
echo Waiting for deployment rollout to complete...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed or timed out.
    echo To rollback, run: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    exit /b 1
)

echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo Fetching application URL from ingress...
for /f "delims=" %%i in ('kubectl get ingress modresorts-ingress -n !NAMESPACE! -o jsonpath^="{.status.loadBalancer.ingress[0].hostname}" 2^>nul') do set INGRESS_HOST=%%i
if "!INGRESS_HOST!"=="" (
    echo Ingress hostname is still pending. Run the following to check later:
    echo   kubectl get ingress modresorts-ingress -n !NAMESPACE!
) else (
    echo Application URL: http://!INGRESS_HOST!/resorts/
)

REM Cleanup temp files
rmdir /s /q "%TEMP%\modresorts-k8s-deploy"

echo.
echo ============================================
echo   SUCCESS: ModResorts deployed to EKS!
echo ============================================
echo.
echo Useful commands:
echo   kubectl get pods -n !NAMESPACE!
echo   kubectl logs -f deployment/!APP_NAME! -n !NAMESPACE!
echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!

endlocal
