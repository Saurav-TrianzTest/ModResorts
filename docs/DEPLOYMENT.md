# ModResorts - Deployment Guide

## Overview

ModResorts is a Java 8 Servlet web application packaged as a WAR file. This guide covers building the container image, pushing it to a registry, and deploying it to AWS EKS (Elastic Kubernetes Service).

## Prerequisites and System Requirements

### For Local Development (Docker Compose)
- Docker 20.10+
- Docker Compose 1.29+

### For AWS EKS Deployment
- Docker 20.10+
- AWS CLI 2.x
- kubectl 1.25+
- eksctl 0.149+ (optional, for cluster creation)
- IAM permissions for ECR, EKS, and EC2

### Java Requirements
- Java 8 (JDK 8) - the application is compiled with `maven.compiler.source` and `maven.compiler.target` set to 1.8

## Local Setup with Docker Compose

1. Ensure Docker is running.
2. Set the required environment variables:
   ```bash
   export WEATHER_API_KEY="your-weather-api-key"
   ```
3. Build and start the application:
   ```bash
   docker-compose up --build
   ```
4. Access the application at `http://localhost:8080`.
5. Check the health endpoint at `http://localhost:8080/health`.

## Building and Pushing the Container Image

### Option 1: AWS ECR (Recommended for EKS)

1. Ensure you are authenticated with AWS:
   ```bash
   aws configure
   ```

2. Run the build and push script:
   ```bash
   ./scripts/build-push.sh
   ```

3. When prompted:
   - Select `1` for AWS ECR
   - Enter your AWS region (e.g., `us-east-1`)
   - Enter your AWS account ID
   - Enter the ECR repository name (or press Enter for default `modresorts`)
   - Enter the image tag (or press Enter for `latest`)

4. The script will:
   - Log in to AWS ECR
   - Create the ECR repository if it does not exist
   - Build the Docker image
   - Push the image to ECR

### Option 2: Docker Hub

1. Run the build and push script:
   ```bash
   ./scripts/build-push.sh
   ```

2. When prompted:
   - Select `2` for Docker Hub
   - Enter your Docker Hub username and password
   - Enter the image name (or press Enter for default `modresorts`)
   - Enter the image tag (or press Enter for `latest`)

### Windows (PowerShell / CMD)

Use the batch script:
```cmd
scripts\build-push.bat
```

## AWS EKS Deployment

### EKS Cluster Setup

If you do not already have an EKS cluster:

1. Create an EKS cluster using eksctl:
   ```bash
   eksctl create cluster \
     --name my-cluster \
     --region us-east-1 \
     --nodegroup-name standard-workers \
     --node-type t3.medium \
     --nodes 2 \
     --nodes-max 4 \
     --managed
   ```

2. Update your kubeconfig:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name my-cluster
   ```

3. Verify connectivity:
   ```bash
   kubectl cluster-info
   ```

### Deploying the Application

1. Ensure you have pushed the container image to ECR (see above).

2. Run the deploy script:
   ```bash
   ./scripts/deploy-image.sh
   ```

3. When prompted:
   - Enter your AWS region
   - Enter your EKS cluster name
   - Enter the full image URI (e.g., `123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:2.0.0`)
   - Enter the `WEATHER_API_KEY` value (for the Kubernetes Secret)
   - Enter `JNDI_FACTORY` and `JNDI_PROVIDER_URL` values (or skip)

4. The script will:
   - Configure kubectl for your EKS cluster
   - Create a Kubernetes Secret with the credentials
   - Apply the namespace, deployment, service, and ingress manifests
   - Wait for the deployment rollout to complete
   - Display the pod, service, and ingress status
   - Show the application URL

### Windows Deployment

Use the batch script:
```cmd
scripts\deploy-image.bat
```

### Kubernetes Manifests

The following manifests are in the `kubernetes/` directory:

- **namespace.yaml**: Creates the `modresorts` namespace.
- **deployment.yaml**: Defines the Deployment with 2 replicas, resource limits, and health probes.
- **service.yaml**: Creates a ClusterIP Service on port 80 targeting container port 8080.
- **ingress.yaml**: Creates an Ingress with the AWS Load Balancer Controller annotations for internet-facing access.

### Manual Deployment

You can also apply the manifests manually:

```bash
# Create namespace
kubectl apply -f kubernetes/namespace.yaml

# Create secret (replace values with your own)
kubectl create secret generic modresorts-secrets \
  -n modresorts \
  --from-literal=weather-api-key="your-api-key" \
  --dry-run=client -o yaml | kubectl apply -f -

# Update image URI in deployment.yaml
sed -i 's|{{IMAGE_URI}}|123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:2.0.0|g' kubernetes/deployment.yaml

# Apply deployment
kubectl apply -f kubernetes/deployment.yaml

# Apply service and ingress
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
kubectl rollout status deployment/modresorts -n modresorts
```

### Rollback

If the deployment fails, you can rollback:

```bash
kubectl rollout undo deployment/modresorts -n modresorts
```

## Configuration Management

The application reads the following environment variables:

| Variable | Description | Required |
|---|---|---|
| `WEATHER_API_KEY` | API key for the weather service (stored in Kubernetes Secret) | Yes |
| `JNDI_FACTORY` | JNDI factory class for service discovery (default: `com.sun.jndi.rmi.registry.RegistryContextFactory`) | No |
| `JNDI_PROVIDER_URL` | JNDI provider URL (default: `localhost:1099`) | No |
| `JAVA_OPTS` | JVM options (default: `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`) | No |

### Kubernetes Secret

The `WEATHER_API_KEY` credential is stored in a Kubernetes Secret named `modresorts-secrets` in the `modresorts` namespace. Non-credential configuration is provided via environment variables in the deployment manifest.

## Security Considerations and Best Practices

1. **Secrets Management**: Credentials are stored in Kubernetes Secrets, never in plain text in the deployment manifest.
2. **Non-root User**: The container runs as a non-root user (`modresorts`).
3. **Minimal Base Image**: The runtime uses `eclipse-temurin:8-jdk` with no package managers installed.
4. **Health Probes**: Liveness and readiness probes use the `/health` endpoint.
5. **Resource Limits**: CPU and memory limits are set to prevent resource exhaustion.
6. **Network Security**: Consider adding Kubernetes NetworkPolicies to restrict pod-to-pod traffic.
7. **IAM Roles**: Use IRSA (IAM Roles for Service Accounts) for AWS resource access.

## Java Notes

### JVM Settings

The container sets the following JVM options:
- `-Xmx512m`: Maximum heap size of 512 MB
- `-Xms256m`: Initial heap size of 256 MB
- `-XX:+UseContainerSupport`: Enables container-aware JVM features
- `-XX:MaxRAMPercentage=75.0`: Uses up to 75% of the container's memory limit for the heap

The container's memory limit is set to 1Gi, so the JVM heap will be approximately 768 MB (75% of 1Gi), leaving room for non-heap memory.

### Servlet Container

The application is packaged as a WAR file and deployed to Apache Tomcat 8.5, which is downloaded during the Docker build and bundled in the runtime image. The WAR is deployed as the ROOT application, so it is served at the root context path (`/`).

### Health Endpoint

The application provides a `/health` endpoint that returns `{"status":"UP"}` with HTTP 200. This endpoint is used by Kubernetes liveness and readiness probes.

### Application Ports

The application listens on port 8080 (Tomcat default). The Kubernetes Service maps port 80 to the container's port 8080.

### Spring Profiles

This application does not use Spring Boot or Spring profiles. It is a standard Java Servlet application.
