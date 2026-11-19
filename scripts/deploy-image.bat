@echo off
setlocal enabledelayedexpansion

set PROJECT_NAME=ModResorts
REM Pre-sanitized name (lowercase, alphanumeric)
set IMAGE_NAME=modresorts

echo === ModResorts EKS Deployment ===
echo.

set /p AWS_REGION="Enter AWS region (e.g., us-east-1) "
set /p CLUSTER_NAME="Enter EKS cluster name "
set /p IMAGE_URI="Enter full image URI (registry/repository-tag) "

set /p JNDI_FACTORY="Enter value for JNDI_FACTORY (or press Enter to skip) "
set /p JNDI_PROVIDER_URL="Enter value for JNDI_PROVIDER_URL (or press Enter to skip) "
set /p HOSTNAME="Enter value for HOSTNAME (or press Enter to skip) "
set /p SERVER_NAME="Enter value for SERVER_NAME (or press Enter to skip) "

REM Credentials - use PowerShell to read without echoing
echo Enter value for WEATHER_API_KEY (or press Enter to skip)
call powershell -Command "$p = Read-Host -AsSecureString; $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)" > tmp_cred_1.txt
set /p WEATHER_API_KEY=<tmp_cred_1.txt
del tmp_cred_1.txt

echo Enter value for CUSTOMER_INFO (or press Enter to skip)
call powershell -Command "$p = Read-Host -AsSecureString; $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)" > tmp_cred_2.txt
set /p CUSTOMER_INFO=<tmp_cred_2.txt
del tmp_cred_2.txt

echo.
echo === Configuring kubectl for EKS cluster ===
call aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (echo Failed to configure kubectl ^& exit /b 1)
kubectl cluster-info
if !ERRORLEVEL! neq 0 (echo kubectl cluster-info failed ^& exit /b 1)

echo.
echo === Applying namespace ===
kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (echo Failed to apply namespace ^& exit /b 1)

echo.
echo === Creating Kubernetes Secret ===
set SECRET_ARGS=
if not "!WEATHER_API_KEY!"=="" set SECRET_ARGS=!SECRET_ARGS! --from-literal=weather-api-key=!WEATHER_API_KEY!
if not "!CUSTOMER_INFO!"=="" set SECRET_ARGS=!SECRET_ARGS! --from-literal=customer-info=!CUSTOMER_INFO!

if not "!SECRET_ARGS!"=="" (
  kubectl create secret generic !IMAGE_NAME!-secrets -n !IMAGE_NAME! !SECRET_ARGS! --dry-run=client -o yaml | kubectl apply -f -
  if !ERRORLEVEL! neq 0 (echo Failed to create secret ^& exit /b 1)
)

echo.
echo === Updating deployment manifest ===
copy /Y kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{JNDI_FACTORY}}', '!JNDI_FACTORY!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{JNDI_PROVIDER_URL}}', '!JNDI_PROVIDER_URL!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{HOSTNAME}}', '!HOSTNAME!' | Set-Content kubernetes\deployment.yaml"
powershell -Command "(Get-Content kubernetes\deployment.yaml) -replace '{{SERVER_NAME}}', '!SERVER_NAME!' | Set-Content kubernetes\deployment.yaml"
del /Q kubernetes\deployment.yaml.bak

echo.
echo === Applying deployment ===
kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (echo Failed to apply deployment ^& exit /b 1)

echo.
echo === Applying service ===
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (echo Failed to apply service ^& exit /b 1)

echo.
echo === Applying ingress ===
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (echo Failed to apply ingress ^& exit /b 1)

echo.
echo === Waiting for deployment rollout ===
kubectl rollout status deployment\!IMAGE_NAME! -n !IMAGE_NAME!
if !ERRORLEVEL! neq 0 (echo Rollout failed ^& exit /b 1)

echo.
echo === Deployed resources ===
kubectl get pods,svc,ingress -n !IMAGE_NAME!

echo.
echo === Application URL ===
echo https://!IMAGE_NAME!.example.com

echo.
echo === Deployment complete ===
echo If you need to rollback, run:
echo   kubectl rollout undo deployment\!IMAGE_NAME! -n !IMAGE_NAME!

endlocal
