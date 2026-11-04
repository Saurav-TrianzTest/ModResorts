# ModResortsContainer Deployment Guide

## Overview

ModResortsContainer is a Java 8 web application built with Maven. It was originally deployed on IBM WebSphere Application Server and has been migrated to run as a portable WAR file on Apache Tomcat inside a Docker container, ready for deployment on AWS EKS (Elastic Kubernetes Service).

The application exposes servlets for weather data, resort availability, user management, and a health check endpoint at `/health`.

## Prerequisites

### System Requirements

- **Java 8** (JDK 1.8) — the application targets Java 8
- **Maven 3.6+** — for building the WAR file
- **Docker 20.10+** — for building and running the container image
- **AWS CLI 2** — for ECR authentication and EKS configuration
- **kubectl 1.24+** — for deploying to EKS
- **eksctl** (optional but recommended) — for EKS cluster creation

### AWS Prerequisites

- An AWS account with permissions to create ECR repositories, EKS clusters, and IAM roles
- IAM permissions: `ecr:*`, `eks:*`, `sts:GetCallerIdentity`
- An ECR repository (created automatically by the build-push script if it does not exist)
- An EKS cluster (created separately or via eksctl)

## Local Setup with Docker Compose

1. Ensure Docker is running.
2. Set the required environment variable:

   ```bash
   export WEATHER_API_KEY="your-weather-api-key"
   ```

3. Build and start the application locally:

   ```bash
   docker-compose up --build
   ```

4. The application will be available at `http://localhost:8080`.

## Building and Pushing the Container Image

### Using the build-push script (Linux/macOS)

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

The script will:
1. Ask you to select a target platform (AWS ECR or Docker Hub).
2. Ask for the registry details (AWS region and ECR repo name, or Docker Hub credentials).
3. Ask for an image tag (defaults to `latest`).
4. Build the Docker image using the multi-stage `Dockerfile`.
5. Log in to the registry.
6. Create the ECR repository if it does not exist.
7. Push the image.

### Using the build-push script (Windows)

```cmd
scripts\build-push.bat
```

### Manual build

```bash
docker build -f Dockerfile -t <registry>/<repo>:<tag> .
docker push <registry>/<repo>:<tag>
```

The project name is `modresortscontainer` (derived from `ModResortsContainer`).

## Kubernetes Deployment (AWS EKS)

### Cluster Setup

If you do not have an EKS cluster yet, create one:

```bash
eksctl create cluster --name <cluster-name> --region <aws-region> --version 1.27
```

Or use the AWS Management Console / eksctl.

### kubectl Configuration

Configure kubectl to point to your EKS cluster:

```bash
aws eks update-kubeconfig --region <aws-region> --name <cluster-name>
```

Verify connectivity:

```bash
kubectl cluster-info
```

### Deployment Walkthrough

The Kubernetes manifests are in the `kubernetes/` directory:

1. **namespace.yaml** — Creates a dedicated namespace `modresortscontainer` for the application.
2. **deployment.yaml** — Defines a Deployment with 2 replicas. The container image URI is a placeholder `{{IMAGE_URI}}` that the deploy script replaces. The container listens on port 8080. Environment variables for external dependencies (e.g., `WEATHER_API_KEY`) are injected from a Kubernetes Secret. Resources requests and limits are set. Liveness and readiness probes hit the `/health` endpoint.
3. **service.yaml** — Exposes the application internally via a ClusterIP Service on port 80.
4. **ingress.yaml** — Creates an AWS ALB Ingress routing traffic from `modresortscontainer.example.com` to the Service.

### Deploying

Run the deploy script:

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will:
1. Ask for the AWS region and EKS cluster name.
2. Ask for the full image URI (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/modresortscontainer:latest`).
3. Ask for environment variable values (e.g., `WEATHER_API_KEY`).
4. Configure kubectl for the EKS cluster.
5. Apply the namespace manifest.
6. Create a Kubernetes Secret (`modresortscontainer-secrets`) with the provided credentials.
7. Replace placeholders in `deployment.yaml` and apply it.
8. Apply the Service and Ingress manifests.
9. Wait for the deployment rollout to complete.
10. Display the pods, services, and ingress details.

### Rollback

If the deployment fails or the new version has issues:

```bash
kubectl rollout undo deployment/modresortscontainer -n modresortscontainer
```

## Configuration Management

### Environment Variables

| Variable | Description | Source |
|---|---|---|
| `WEATHER_API_KEY` | API key for the weather data service | Kubernetes Secret |
| `JAVA_OPTS` | JVM options for container tuning | Deployment env |
| `TZ` | Timezone (UTC) | Deployment env |

### Secrets

All credentials are stored in a Kubernetes Secret named `modresortscontainer-secrets` in the `modresortscontainer` namespace. The deploy script creates this Secret using `kubectl create secret generic`.

## Security Considerations

- **Non-root user**: The container runs as user 1000 (non-root).
- **Secrets management**: Credentials are stored in Kubernetes Secrets, never in plaintext in the manifests.
- **Health checks**: The `/health` endpoint returns `{"status": "UP"}` and is used for liveness and readiness probes.
- **Image scanning**: Regularly scan the container image for vulnerabilities.
- **Network policies**: Consider adding Kubernetes NetworkPolicies to restrict pod-to-pod traffic.
- **IAM roles**: Use IRSA (IAM Roles for Service Accounts) if the application needs AWS API access.

## Java Notes

### JVM Settings

The container uses the following JVM settings via `JAVA_OPTS`:

- `-Xmx512m` — Maximum heap size of 512MB
- `-Xms256m` — Initial heap size of 256MB
- `-XX:+UseContainerSupport` — Enables container-aware memory limits (Java 8)
- `-XX:MaxRAMPercentage=75.0` — Uses up to 75% of the container's memory limit for the JVM

These settings align with the Kubernetes resource limits (512Mi request, 1Gi limit). The JVM will not exceed 75% of the container's memory, preventing OOM kills while leaving room for off-heap memory.

### Build Stage

The Docker build uses `maven:3.9.4-eclipse-temurin-8` as the build stage, matching the project's Java 8 compiler level (`maven.compiler.source` and `maven.compiler.target` are both `1.8`).

### Runtime Stage

The runtime stage is based on `eclipse-temurin:8-jdk` as specified. Apache Tomcat 8.5 is copied from the official `tomcat:8.5.95-jdk8-openjdk` image. The WAR file is deployed as `ROOT.war` so it serves at the root context path.

### Health Endpoint

The application exposes a health check endpoint at `GET /health` that returns:

```json
{"status": "UP"}
```

This endpoint is always available from application startup and is used by the Kubernetes liveness and readiness probes.
