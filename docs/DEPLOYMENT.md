# ModResorts - Deployment Guide

## Overview

ModResorts is a Java web application built with Maven, packaged as a WAR file, and deployed on Apache Tomcat 8.5. This guide covers building, pushing, and deploying the application to AWS EKS (Elastic Kubernetes Service).

## System Requirements

### Prerequisites

- **Java 8** (JDK) - for local builds
- **Maven 3.8+** - for building the project
- **Docker** - for building and pushing container images
- **AWS CLI** - for ECR authentication and EKS configuration
- **kubectl** - for deploying to EKS
- **eksctl** (optional) - for EKS cluster creation

### AWS Permissions

The deploying user/role must have permissions for:
- `ecr:*` - to create repositories and push images
- `eks:*` - to describe clusters and update kubeconfig
- `sts:GetCallerIdentity` - to verify AWS credentials

## Local Setup

### Building Locally

```bash
mvn clean package -DskipTests
```

The WAR file will be produced at `target/modresorts-2.0.0.war`.

### Running with Docker Compose

```bash
# Set required environment variables
export WEATHER_API_KEY="your-weather-api-key"

# Build and start
docker-compose up --build
```

The application will be available at `http://localhost:8080`.

## Building and Pushing to ECR

### Using the build script (Linux/macOS)

```bash
scripts/build-push.sh
```

### Using the build script (Windows)

```cmd
scripts\build-push.bat
```

The script will prompt for:
1. **AWS region** (e.g., `us-east-1`)
2. **ECR registry URL** (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com`)
3. **ECR repository name** (defaults to `modresorts`)
4. **Image tag** (defaults to `latest`)

The script will:
1. Log in to ECR using `aws ecr get-login-password`
2. Create the ECR repository if it doesn't exist
3. Build the Docker image using the multi-stage Dockerfile
4. Push the image to ECR

## AWS EKS Deployment

### EKS Cluster Setup

If you don't have an EKS cluster, create one using eksctl:

```bash
eksctl create cluster \
  --name modresorts-cluster \
  --region us-east-1 \
  --nodegroup-name modresorts-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-max 4
```

Or create via AWS Console and configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name modresorts-cluster
```

### Deploying to EKS

```bash
scripts/deploy-image.sh
```

### Using the deploy script (Windows)

```cmd
scripts\deploy-image.bat
```

The script will prompt for:
1. **AWS region** (e.g., `us-east-1`)
2. **EKS cluster name**
3. **Image URI** (full path with registry and tag)
4. **Environment variables**: `JAVA_NAMING_FACTORY_INITIAL`, `JAVA_NAMING_PROVIDER_URL`
5. **Credentials**: `WEATHER_API_KEY` (input not echoed)

The script will:
1. Configure kubectl for the EKS cluster
2. Create the namespace (`modresorts`)
3. Create a Kubernetes Secret for credentials
4. Replace placeholders in `kubernetes/deployment.yaml`
5. Apply namespace, deployment, service, and ingress manifests
6. Wait for the deployment rollout to complete
7. Display cluster resources and application URL

### Kubernetes Manifests

The `kubernetes/` directory contains:

- **namespace.yaml** - Creates the `modresorts` namespace
- **deployment.yaml** - Defines the Deployment with 2 replicas, resource limits, and health probes
- **service.yaml** - Exposes the application via a ClusterIP service on port 80
- **ingress.yaml** - Configures an AWS ALB ingress for external access

### Manual Deployment Steps

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name modresorts-cluster

# Create namespace
kubectl apply -f kubernetes/namespace.yaml

# Create secret for credentials
kubectl create secret generic modresorts-secrets -n modresorts \
  --from-literal=weather-api-key=YOUR_API_KEY \
  --dry-run=client -o yaml | kubectl apply -f -

# Replace placeholders in deployment.yaml
sed -i.bak 's|{{IMAGE_URI}}|123456789012.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest|g' kubernetes/deployment.yaml
sed -i.bak 's|{{NAMESPACE}}|modresorts|g' kubernetes/deployment.yaml
sed -i.bak 's|{{JAVA_NAMING_FACTORY_INITIAL}}||g' kubernetes/deployment.yaml
sed -i.bak 's|{{JAVA_NAMING_PROVIDER_URL}}||g' kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

# Apply manifests
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
kubectl rollout status deployment/modresorts -n modresorts
```

## Configuration Management

### Environment Variables

| Variable | Description | Required |
|---|---|---|
| `WEATHER_API_KEY` | Weather Underground API key (stored in Kubernetes Secret) | Yes |
| `JAVA_NAMING_FACTORY_INITIAL` | JNDI initial context factory class | No |
| `JAVA_NAMING_PROVIDER_URL` | JNDI provider URL | No |
| `JAVA_OPTS` | JVM options | No (defaults applied) |
| `TZ` | Timezone | No (defaults to UTC) |

### Kubernetes Secrets

Credentials are stored as Kubernetes Secrets and referenced via `secretKeyRef` in the deployment:

```yaml
- name: WEATHER_API_KEY
  valueFrom:
    secretKeyRef:
      name: modresorts-secrets
      key: weather-api-key
```

## Security Considerations

- **Non-root user**: The container runs as a non-root `tomcat` user
- **Secrets management**: Credentials are stored in Kubernetes Secrets, never in plain text
- **No hardcoded credentials**: All credentials come from environment variables or Kubernetes Secrets
- **Health endpoint**: The `/health` endpoint returns `{"status":"UP"}` without exposing sensitive information
- **Resource limits**: CPU and memory limits are set to prevent resource exhaustion
- **Image scanning**: Scan the ECR image for vulnerabilities before deployment

## Java Notes

### JVM Settings

The container uses the following JVM settings (configurable via `JAVA_OPTS`):

- `-Xmx512m` - Maximum heap size of 512 MB
- `-Xms256m` - Initial heap size of 256 MB
- `-XX:+UseContainerSupport` - Enables container-aware memory management
- `-XX:MaxRAMPercentage=75.0` - Maximum RAM usage capped at 75% of container limit

These settings align with the container's memory limit of 1Gi, ensuring the JVM respects container boundaries.

### Spring Profiles

This application does not use Spring Boot; it is a standard Java Servlet web application deployed on Apache Tomcat. There are no Spring profiles to configure.

### Health Endpoint

The application exposes a health check endpoint at `/health` that returns:

```json
{"status":"UP"}
```

This endpoint is used by Kubernetes liveness and readiness probes:

- **Liveness probe**: `httpGet` on `/health` at port 8080, with 30s initial delay
- **Readiness probe**: `httpGet` on `/health` at port 8080, with 15s initial delay

### Application Port

The application listens on port **8080** (Tomcat default HTTP port). The Kubernetes Service maps port 80 to container port 8080.

### Servlet API

The application uses the Java Servlet API 3.1 (via `javax.javaee-api:7.0`). The `@WebServlet` annotation is used for servlet registration, and `web.xml` provides additional configuration.

## Troubleshooting

### Pod Failures

```bash
# Check pod status
kubectl get pods -n modresorts

# View pod logs
kubectl logs -f deployment/modresorts -n modresorts

# Describe pod for events
kubectl describe pod <pod-name> -n modresorts
```

### Service Issues

```bash
# Check service
kubectl get svc -n modresorts

# Test service connectivity from within the cluster
kubectl run debug --rm -it --image=curlimages/curl -- sh
# Then: curl http://modresorts-service:80/health
```

### Ingress Problems

```bash
# Check ingress status
kubectl get ingress -n modresorts

# Check ingress events
kubectl describe ingress modresorts-ingress -n modresorts

# Verify ALB was created
kubectl get ingress -n modresorts -o wide
```

## Scaling and Management

### Horizontal Pod Autoscaler

```bash
kubectl autoscale deployment modresorts --cpu-percent=60 --min=2 --max=10 -n modresorts
```

### Rolling Updates

```bash
# Update the image
kubectl set image deployment/modresorts modresorts=<new-image-uri> -n modresorts

# Monitor rollout
kubectl rollout status deployment/modresorts -n modresorts
```

### Rollbacks

```bash
# Rollback to previous revision
kubectl rollout undo deployment/modresorts -n modresorts

# Rollback to a specific revision
kubectl rollout history deployment/modresorts -n modresorts
kubectl rollout undo deployment/modresorts --to-revision=2 -n modresorts
```
