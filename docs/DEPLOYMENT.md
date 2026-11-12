# ModResortsConatinr - Deployment Guide

## Overview

ModResortsConatinr is a Java 8 web application built with Maven, packaged as a WAR file, and deployed on Apache Tomcat 8. This guide covers building, pushing, and deploying the application to AWS EKS (Elastic Kubernetes Service).

## Prerequisites

### System Requirements
- Java 8 (JDK 1.8)
- Maven 3.6+
- Docker 20.10+
- AWS CLI 2.x
- kubectl 1.21+
- eksctl 0.100+
- PowerShell (for Windows batch scripts)

### AWS EKS Prerequisites
- An AWS account with permissions to create ECR repositories, EKS clusters, and IAM roles
- IAM permissions for ECR, EKS, and EC2
- An EKS cluster (create one with eksctl if you don't have one)

## Local Setup with Docker Compose

1. Build the image:
   ```bash
   docker build -f Dockerfile -t modresortsconatinr:latest .
   ```

2. Run with Docker Compose:
   ```bash
   WEATHER_API_KEY=your-key docker-compose up
   ```

3. Access the application at `http://localhost:8080`

## Building and Pushing the Image

### Using build-push.sh (Linux/macOS)
```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

The script will:
1. Ask you to choose between AWS ECR and Docker Hub
2. Ask for the target platform details (AWS region, account ID for ECR, or Docker Hub credentials)
3. Ask for an image tag (or press Enter for `latest`)
4. Build the Docker image
5. Log in to the registry
6. Create the ECR repository if it doesn't exist (for ECR)
7. Push the image

### Using build-push.bat (Windows)
```cmd
scripts\build-push.bat
```

## Deploying to AWS EKS

### Cluster Setup

If you don't have an EKS cluster, create one:
```bash
eksctl create cluster --name modresortsconatinr-cluster --region us-east-1 --nodegroup-name modresortsconatinr-nodes --node-type t3.medium --nodes 2 --nodes-max 4
```

Configure kubectl:
```bash
aws eks update-kubeconfig --region us-east-1 --name modresortsconatinr-cluster
```

### Deploying the Application

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will:
1. Ask for the AWS region and EKS cluster name
2. Configure kubectl for the cluster
3. Ask for the image URI (full path with registry and tag)
4. Ask for environment variables (JAVA_NAMING_FACTORY_INITIAL, JAVA_NAMING_PROVIDER_URL, DATASOURCE_JNDI)
5. Ask for the WEATHER_API_KEY credential (input is hidden)
6. Create a Kubernetes Secret for the credential
7. Replace placeholders in the deployment manifest
8. Apply the namespace, deployment, service, and ingress
9. Wait for the deployment to be ready
10. Show the deployment status and application URL

### Windows Deployment
```cmd
scripts\deploy-image.bat
```

## Kubernetes Manifests

The application uses the following Kubernetes resources in the `kubernetes/` directory:

- **namespace.yaml**: Creates the `modresortsconatinr` namespace
- **deployment.yaml**: Defines the Deployment with 2 replicas, resource limits, liveness and readiness probes
- **service.yaml**: Creates a ClusterIP service mapping port 80 to container port 8080
- **ingress.yaml**: Creates an AWS ALB ingress with the host `modresortsconatinr.example.com`

## Configuration Management

The application reads the following environment variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `WEATHER_API_KEY` | Weather Underground API key (stored in Kubernetes Secret) | No (app uses cached data if not set) |
| `JAVA_NAMING_FACTORY_INITIAL` | JNDI initial context factory class | No |
| `JAVA_NAMING_PROVIDER_URL` | JNDI provider URL | No |
| `DATASOURCE_JNDI` | JNDI name for the datasource | No (demo mode if not set) |

### Kubernetes Secret

The `WEATHER_API_KEY` credential is stored in a Kubernetes Secret named `modresortsconatinr-secrets` in the `modresortsconatinr` namespace. The deploy script creates this secret automatically.

## Health Check Endpoint

The application exposes a health check endpoint at `/health` that returns `{"status":"UP"}` with HTTP 200. This endpoint is used by:
- Kubernetes liveness probe (initial delay: 60s, period: 30s)
- Kubernetes readiness probe (initial delay: 30s, period: 10s)
- AWS ALB ingress health check (path: `/health`)

## Security Considerations

1. **Non-root user**: The container runs as a non-root user (`appuser`)
2. **Secrets management**: Credentials are stored in Kubernetes Secrets, never in plaintext in manifests
3. **TLS**: Configure TLS termination at the ALB level for production
4. **Network policies**: Consider adding Kubernetes Network Policies to restrict traffic
5. **Image scanning**: Scan container images for vulnerabilities before pushing to ECR

## Java Notes

### JVM Settings
The container uses the following JVM settings via `JAVA_OPTS`:
- `-Xmx512m`: Maximum heap size of 512MB
- `-Xms256m`: Initial heap size of 256MB
- `-XX:+UseContainerSupport`: Enable container-aware JVM features
- `-XX:MaxRAMPercentage=75.0`: Use up to 75% of container memory for the heap

These settings are tuned for the Kubernetes resource limits (512Mi requests, 1Gi limits).

### Spring Profiles
This application does not use Spring Boot. It is a traditional Java EE web application deployed on Apache Tomcat 8. No Spring profiles are configured.

### Servlet Container
The application runs on Apache Tomcat 8.5.92, which is included in the Docker image. The container exposes port 8080 for HTTP traffic.

### Health Endpoint
The `/health` endpoint is a simple servlet that returns `{"status":"UP"}` with HTTP 200 status code. It is registered both via `@WebServlet` annotation and in `web.xml` for reliability.

## Troubleshooting

### Pod Failures
- Check pod logs: `kubectl logs -n modresortsconatinr <pod-name>`
- Describe pod: `kubectl describe pod -n modresortsconatinr <pod-name>`
- Check events: `kubectl get events -n modresortsconatinr --sort-by='.lastTimestamp'`

### Service Issues
- Verify the service exists: `kubectl get svc -n modresortsconatinr`
- Check endpoints: `kubectl get endpoints -n modresortsconatinr`

### Ingress Problems
- Check ingress status: `kubectl get ingress -n modresortsconatinr`
- Verify the ALB was created: `kubectl describe ingress -n modresortsconatinr modresortsconatinr-ingress`
- Check AWS console for the load balancer

### Rollback
To rollback a failed deployment:
```bash
kubectl rollout undo deployment/modresortsconatinr -n modresortsconatinr
```

## Scaling and Management

### Horizontal Pod Autoscaler
To enable auto-scaling:
```bash
kubectl autoscale deployment modresortsconatinr --cpu-percent=70 --min=2 --max=10 -n modresortsconatinr
```

### Rolling Updates
Update the image by changing the tag in the deployment and applying:
```bash
kubectl set image deployment/modresortsconatinr modresortsconatinr=<new-image-uri> -n modresortsconatinr
```

Monitor the rollout:
```bash
kubectl rollout status deployment/modresortsconatinr -n modresortsconatinr
```
