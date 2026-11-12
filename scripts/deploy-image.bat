@echo off
setlocal enabledelayedexpansion

REM Deploy script for modresorts to AWS EKS
REM Runs from the repository root, never changes directory

set "PROJECT_NAME=modresorts"
set "IMAGE_NAME=%PROJECT_NAME%"
set "NAMESPACE=%IMAGE_NAME%"

echo === ModResorts EKS Deployment ===
echo Namespace: %NAMESPACE%
echo.

REM Ask for AWS region
set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
if "!AWS_REGION!"=="" (
    echo AWS region is required.
    exit /b 1
)

REM Ask for EKS cluster name
set /p CLUSTER_NAME="Enter EKS cluster name: "
if "!CLUSTER_NAME!"=="" (
    echo EKS cluster name is required.
    exit /b 1
)

REM Ask for image URI
set /p IMAGE_URI="Enter full image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest): "
if "!IMAGE_URI!"=="" (
    echo Image URI is required.
    exit /b 1
)

REM Ask for environment variables
echo.
echo === Environment Variables ===
echo Enter values for the environment variables the application needs.
echo Press Enter to skip (leave placeholder for manual configuration).
echo.

set /p JAVA_NAMING_FACTORY_INITIAL="Enter value for JAVA_NAMING_FACTORY_INITIAL (or press Enter to skip): "
set /p JAVA_NAMING_PROVIDER_URL="Enter value for JAVA_NAMING_PROVIDER_URL (or press Enter to skip): "

REM Ask for WEATHER_API_KEY (credential)
echo.
echo === Credentials ===
echo Enter values for credentials. Input will not be echoed.
echo.
set /p WEATHER_API_KEY="Enter WEATHER_API_KEY value (or press Enter to skip): "
echo.

REM Configure kubectl for EKS
echo.
echo === Configuring kubectl for EKS ===
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo Failed to configure kubectl for EKS cluster.
    exit /b 1
)
echo kubectl configured successfully.
echo.

REM Verify cluster connectivity
echo === Verifying cluster connectivity ===
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo Failed to connect to cluster.
    exit /b 1
)
echo.

REM Apply namespace
echo === Applying namespace ===
kubectl apply -f kubernetes/namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply namespace.
    exit /b 1
)
echo Namespace applied.
echo.

REM Create Secret for credentials
echo === Creating Kubernetes Secret ===
set "SECRET_ARGS="
if not "!WEATHER_API_KEY!"=="" (
    set "SECRET_ARGS=--from-literal=weather-api-key=!WEATHER_API_KEY!"
)

if not "!SECRET_ARGS!"=="" (
    kubectl create secret generic !NAMESPACE!-secrets -n !NAMESPACE! !SECRET_ARGS! --dry-run=client -o yaml | kubectl apply -f -
    if !ERRORLEVEL! neq 0 (
        echo Failed to create secret.
        exit /b 1
    )
    echo Secret created.
) else (
    echo No credentials provided. Skipping secret creation.
)
echo.

REM Replace placeholders in deployment.yaml
echo === Preparing deployment manifest ===
copy /Y kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul

powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Out-File -Encoding UTF8 kubernetes\deployment.yaml.tmp"
move /Y kubernetes\deployment.yaml.tmp kubernetes\deployment.yaml >nul
powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{NAMESPACE}}', '!NAMESPACE!' | Out-File -Encoding UTF8 kubernetes\deployment.yaml.tmp"
move /Y kubernetes\deployment.yaml.tmp kubernetes\deployment.yaml >nul
powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{JAVA_NAMING_FACTORY_INITIAL}}', '!JAVA_NAMING_FACTORY_INITIAL!' | Out-File -Encoding UTF8 kubernetes\deployment.yaml.tmp"
move /Y kubernetes\deployment.yaml.tmp kubernetes\deployment.yaml >nul
powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{JAVA_NAMING_PROVIDER_URL}}', '!JAVA_NAMING_PROVIDER_URL!' | Out-File -Encoding UTF8 kubernetes\deployment.yaml.tmp"
move /Y kubernetes\deployment.yaml.tmp kubernetes\deployment.yaml >nul

del /Q kubernetes\deployment.yaml.bak >nul 2>&1
echo Deployment manifest prepared.
echo.

REM Apply deployment
echo === Applying deployment ===
kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply deployment.
    exit /b 1
)
echo Deployment applied.
echo.

REM Apply service
echo === Applying service ===
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply service.
    exit /b 1
)
echo Service applied.
echo.

REM Apply ingress
echo === Applying ingress ===
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply ingress.
    exit /b 1
)
echo Ingress applied.
echo.

REM Wait for deployment rollout
echo === Waiting for deployment rollout ===
kubectl rollout status deployment/!IMAGE_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo Deployment rollout failed.
    exit /b 1
)
echo.

REM Show resources
echo === Cluster Resources ===
kubectl get pods,svc,ingress -n !NAMESPACE!
echo.

REM Show application URL
echo === Application URL ===
echo Application will be available at: http://!NAMESPACE!.example.com
echo.

echo === Deployment Complete ===
echo.
echo Rollback instructions:
echo   kubectl rollout undo deployment/!IMAGE_NAME! -n !NAMESPACE!
echo.
echo To check logs:
echo   kubectl logs -f deployment/!IMAGE_NAME! -n !NAMESPACE!

endlocal
