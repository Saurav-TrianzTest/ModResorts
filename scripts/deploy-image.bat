@echo off
setlocal enabledelayedexpansion

set APP_NAME=modresorts
set NAMESPACE=modresorts

echo ============================================
echo   ModResorts - Deploy to AWS EKS
echo ============================================
echo.

rem Prompt for AWS region
set /p AWS_REGION="Enter AWS Region (e.g. us-east-1): "
if "!AWS_REGION!"=="" (
    echo ERROR: AWS Region is required.
    exit /b 1
)

rem Prompt for EKS cluster name
set /p CLUSTER_NAME="Enter EKS Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: EKS Cluster Name is required.
    exit /b 1
)

rem Prompt for Docker image URI
set /p IMAGE_URI="Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo --- Optional Environment Variable Configuration ---
set /p WEATHER_API_KEY_VAL="Enter value for WEATHER_API_KEY (or press Enter to skip): "
set /p SERVER_DISPLAY_NAME_VAL="Enter value for SERVER_DISPLAY_NAME (or press Enter to skip): "
set /p SERVER_FULL_NAME_VAL="Enter value for SERVER_FULL_NAME (or press Enter to skip): "

echo.
echo Configuring kubectl for EKS cluster: !CLUSTER_NAME! in region: !AWS_REGION!
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
echo Updating Kubernetes manifests with provided values...

rem Create a working copy of deployment.yaml
copy kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul

rem Replace IMAGE_URI placeholder using PowerShell
powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content 'kubernetes\deployment.yaml'"

rem Replace WEATHER_API_KEY placeholder
if "!WEATHER_API_KEY_VAL!"=="" (
    powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '{{WEATHER_API_KEY}}', '' | Set-Content 'kubernetes\deployment.yaml'"
) else (
    powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '{{WEATHER_API_KEY}}', '!WEATHER_API_KEY_VAL!' | Set-Content 'kubernetes\deployment.yaml'"
)

rem Replace SERVER_DISPLAY_NAME placeholder
if "!SERVER_DISPLAY_NAME_VAL!"=="" (
    powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '{{SERVER_DISPLAY_NAME}}', 'modresorts-container' | Set-Content 'kubernetes\deployment.yaml'"
) else (
    powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '{{SERVER_DISPLAY_NAME}}', '!SERVER_DISPLAY_NAME_VAL!' | Set-Content 'kubernetes\deployment.yaml'"
)

rem Replace SERVER_FULL_NAME placeholder
if "!SERVER_FULL_NAME_VAL!"=="" (
    powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '{{SERVER_FULL_NAME}}', 'modresorts-container-01' | Set-Content 'kubernetes\deployment.yaml'"
) else (
    powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '{{SERVER_FULL_NAME}}', '!SERVER_FULL_NAME_VAL!' | Set-Content 'kubernetes\deployment.yaml'"
)

echo.
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply namespace. & goto :restore_and_fail )

echo   [2/4] Applying deployment...
kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply deployment. & goto :restore_and_fail )

echo   [3/4] Applying service...
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply service. & goto :restore_and_fail )

echo   [4/4] Applying ingress...
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply ingress. & goto :restore_and_fail )

rem Restore original deployment.yaml
move /y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul

echo.
echo Waiting for deployment rollout...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed. Running rollback...
    kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    echo Rollback initiated. Check pod status with: kubectl get pods -n !NAMESPACE!
    exit /b 1
)

echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo ============================================
echo   Deployment completed successfully!
echo   Application URL: http://modresorts.example.com
echo.
echo   Useful commands:
echo     kubectl get pods -n !NAMESPACE!
echo     kubectl logs -f deployment/!APP_NAME! -n !NAMESPACE!
echo     kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo ============================================

endlocal
exit /b 0

:restore_and_fail
move /y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul
echo Deployment failed. Original deployment.yaml restored.
endlocal
exit /b 1
