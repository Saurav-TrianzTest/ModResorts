@echo off & setlocal enabledelayedexpansion
rem Deploys the pushed ContainerSanity image to AWS EKS with kubectl.
rem Run from the repository root with scripts\deploy-image.bat

set "APP_NAME=containersanity"
set "NAMESPACE=containersanity"
set "SECRET_NAME=containersanity-secrets"
set "TMP_FILE=%TEMP%\containersanity-deploy.tmp"
set "TEMPLATE_COPY=%TEMP%\containersanity-deployment-template.yaml"

where aws >nul 2>&1
if !ERRORLEVEL! neq 0 (
  echo ERROR - the AWS CLI is not installed
  exit /b 1
)
where kubectl >nul 2>&1
if !ERRORLEVEL! neq 0 (
  echo ERROR - kubectl is not installed
  exit /b 1
)

echo === Deploy !APP_NAME! to AWS EKS ===
set /p AWS_REGION="Enter the AWS region (for example us-east-1): "
set /p CLUSTER_NAME="Enter the EKS cluster name: "
set /p IMAGE_URI="Enter the image URI (registry/repository and tag): "
if "!AWS_REGION!"=="" (
  echo ERROR - the region is required
  exit /b 1
)
if "!CLUSTER_NAME!"=="" (
  echo ERROR - the cluster name is required
  exit /b 1
)
if "!IMAGE_URI!"=="" (
  echo ERROR - the image URI is required
  exit /b 1
)

set "JNDI_INITIAL_CONTEXT_FACTORY="
set "JNDI_PROVIDER_URL="
set "WEATHER_API_KEY="
set /p JNDI_INITIAL_CONTEXT_FACTORY="Enter value for JNDI_INITIAL_CONTEXT_FACTORY (or press Enter to skip): "
set /p JNDI_PROVIDER_URL="Enter value for JNDI_PROVIDER_URL (or press Enter to skip): "

rem The weather API key is a credential: it is read without echo
powershell -NoProfile -Command "$s = Read-Host 'Enter value for WEATHER_API_KEY (or press Enter to skip)' -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))" > "!TMP_FILE!"
set /p WEATHER_API_KEY=<"!TMP_FILE!"
del "!TMP_FILE!" >nul 2>&1

echo Step 1 - configuring kubectl for the cluster
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
  echo ERROR - aws eks update-kubeconfig failed
  exit /b 1
)
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
  echo ERROR - kubectl cannot reach the cluster
  exit /b 1
)

echo Step 2 - filling in the placeholders of kubernetes\deployment.yaml
copy /y "kubernetes\deployment.yaml" "!TEMPLATE_COPY!" >nul
powershell -NoProfile -Command "$c = [IO.File]::ReadAllText('kubernetes\deployment.yaml'); $c = $c.Replace('{{IMAGE_URI}}', $env:IMAGE_URI).Replace('{{NAMESPACE}}', $env:NAMESPACE).Replace('{{JNDI_INITIAL_CONTEXT_FACTORY}}', $env:JNDI_INITIAL_CONTEXT_FACTORY).Replace('{{JNDI_PROVIDER_URL}}', $env:JNDI_PROVIDER_URL); [IO.File]::WriteAllText('kubernetes\deployment.yaml', $c)"
if !ERRORLEVEL! neq 0 (
  echo ERROR - filling in the placeholders failed
  goto fail
)

echo Step 3 - creating the namespace
kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR - applying namespace.yaml failed
  goto fail
)

echo Step 4 - creating the secret !SECRET_NAME!
kubectl create secret generic !SECRET_NAME! -n !NAMESPACE! --from-literal=weather-api-key="!WEATHER_API_KEY!" --dry-run=client -o yaml | kubectl apply -f -
if !ERRORLEVEL! neq 0 (
  echo ERROR - creating the secret failed
  goto fail
)

echo Step 5 - applying the deployment, the service and the ingress
kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR - applying deployment.yaml failed
  goto fail
)
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR - applying service.yaml failed
  goto fail
)
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR - applying ingress.yaml failed
  goto fail
)

echo Step 6 - waiting for the rollout
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
  echo ERROR - the rollout did not finish
  echo Look at the pods with kubectl describe pods -n !NAMESPACE!
  echo Roll back with kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
  goto fail
)

echo Step 7 - the state of the deployment
kubectl get pods,svc,ingress -n !NAMESPACE!

set "APP_URL="
powershell -NoProfile -Command "$h = kubectl get ingress containersanity-ingress -n containersanity -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; if ($h) { 'http' + [char]58 + '//' + $h + '/resorts/' }" > "!TMP_FILE!"
set /p APP_URL=<"!TMP_FILE!"
del "!TMP_FILE!" >nul 2>&1
if "!APP_URL!"=="" (
  echo The load balancer address is not ready yet. Check later with kubectl get ingress -n !NAMESPACE!
) else (
  echo Application URL is !APP_URL!
)

echo To roll back a bad release run kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
call :restore
echo Deployment finished.
endlocal
exit /b 0

:fail
call :restore
echo Deployment failed. To roll back run kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
exit /b 1

:restore
if exist "!TEMPLATE_COPY!" (
  copy /y "!TEMPLATE_COPY!" "kubernetes\deployment.yaml" >nul
  del "!TEMPLATE_COPY!" >nul 2>&1
)
exit /b 0
