# ModResorts Container Deployment Guide

## Overview

This document describes how to build, deploy, and manage the ModResorts application on AWS Elastic Kubernetes Service (EKS). The application is a Java 8 WAR-based web application that runs on Apache Tomcat 8.5 inside a Docker container.

## Prerequisites

### System Requirements

- Java 8 (JDK) — the application is built and runs on Java 8
- Docker 20.10+
- AWS CLI 2.x
- kubectl 1.24+
- eksctl 0.100+
- Maven 3.8+ (for local builds)

### AWS Permissions

The following IAM permissions are required:

- `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`, `ecr:UploadLayerPart`, `ecr:PutLayerPart`, `ecr:InitiateLayerUpload`, `ecr:BatchGetImage`
- `ecr:CreateRepository`, `ecr:DescribeRepositories`
- `eks:DescribeCluster`, `eks:ListClusters`
- `sts:GetCallerIdentity`

## Local Setup with Docker Compose

1. Set the required environment variables:

```bash
export WEATHER_API_KEY="your-weather-api-key"
export CUSTOMER_INFO="customer-info-data"
```

2. Build and run locally:

```bash
docker-compose up --build
```

3. Access the application at `http://localhost:8080/modresorts/` and the health check at `http://localhost:8080/modresorts/health`.

## Building and Pushing to Amazon ECR

### Using the shell script (Linux/macOS)

```bash
./scripts/build-push.sh
```

The script will prompt for:
- AWS region (e.g., `us-east-1`)
- ECR repository name (default: `modresorts`)
- Image tag (default: `latest`)
- AWS account ID

It will then:
1. Log in to Amazon ECR
2. Create the ECR repository if it does not exist
3. Build the Docker image
4. Push the image to ECR

### Using the batch script (Windows)

```cmd
scripts\build-push.bat
```

## Deploying to AWS EKS

### EKS Cluster Setup

1. Create an EKS cluster:

```bash
eksctl create cluster --name modresorts-cluster --region us-east-1 --nodegroup-name modresorts-nodes --node-type t3.medium --nodes 2 --nodes-max 4
```

2. Configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name modresorts-cluster
```

3. Verify the cluster:

```bash
kubectl cluster-info
```

### Deploying the Application

```bash
./scripts/deploy-image.sh
```

The script will prompt for:
- AWS region
- EKS cluster name
- Full image URI (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest`)
- Environment variables for non-credential configuration (`JNDI_FACTORY`, `JNDI_PROVIDER_URL`, `HOSTNAME`, `SERVER_NAME`)
- Credentials without echoing (`WEATHER_API_KEY`, `CUSTOMER_INFO`)

The script will:
1. Configure kubectl for the EKS cluster
2. Apply the namespace manifest
3. Create a Kubernetes Secret for credentials
4. Replace placeholders in the deployment manifest
5. Apply the deployment, service, and ingress manifests
6. Wait for the deployment rollout to complete
7. Display the deployed resources and application URL

### Windows Deployment

```cmd
scripts\deploy-image.bat
```

## Configuration Management

### Environment Variables

The application reads the following environment variables:

| Variable | Description | Required |
|---|---|---|
| `WEATHER_API_KEY` | API key for the weather data service | Yes (for real-time weather) |
| `CUSTOMER_INFO` | Customer information string | No |
| `JNDI_FACTORY` | JNDI initial context factory class | No |
| `JNDI_PROVIDER_URL` | JNDI provider URL | No |
| `HOSTNAME` | Server hostname for environment discovery | No |
| `SERVER_NAME` | Server name for environment discovery | No |

### Kubernetes Secrets

Credentials are stored in a Kubernetes Secret named `modresorts-secrets` in the `modresorts` namespace. The secret keys are:

- `weather-api-key` — for `WEATHER_API_KEY`
- `customer-info` — for `CUSTOMER_INFO`

Non-credential configuration is passed as environment variables in the deployment manifest.

## Kubernetes Manifests

### Namespace

`kubernetes/namespace.yaml` — Creates the `modresorts` namespace.

### Deployment

`kubernetes/deployment.yaml` — Defines a Deployment with:
- 2 replicas for high availability
- Container image (placeholder `{{IMAGE_URI}}` replaced during deployment)
- Container port 8080 (Tomcat HTTP)
- Environment variables for configuration and credentials (from Secret)
- Resource requests (250m CPU, 512Mi memory) and limits (500m CPU, 1Gi memory)
- Liveness probe on `/health` (HTTP GET)
- Readiness probe on `/health` (HTTP GET)

### Service

`kubernetes/service.yaml` — Defines a ClusterIP Service on port 80 routing to the container port 8080.

### Ingress

`kubernetes/ingress.yaml` — Defines an Ingress with the AWS Load Balancer Controller annotations:
- `kubernetes.io/ingress.class: alb`
- `alb.ingress.kubernetes.io/scheme: internet-facing`

Routes traffic from `modresorts.example.com` to the Service.

## Security Considerations

- **Credentials**: All sensitive values (API keys, customer info) are stored in Kubernetes Secrets, never in plain text in the deployment manifest.
- **Non-root user**: The Docker image runs as a non-root user (`appuser`) for least-privilege operation.
- **Health endpoint**: The `/health` endpoint returns `{"status":"UP"}` and is used for Kubernetes liveness and readiness probes.
- **No hardcoded credentials**: All credentials are provided via environment variables or Kubernetes Secrets at deploy time.
- **Image scanning**: It is recommended to scan the container image for vulnerabilities before pushing to ECR.

## Scaling and Management

### Horizontal Pod Autoscaler

To scale based on CPU utilization:

```bash
kubectl autoscale deployment modresorts --cpu-percent=60 --min=2 --max=10 -n modresorts
```

### Rolling Updates

```bash
kubectl set image deployment/modresorts modresorts=<new-image-uri> -n modresorts
kubectl rollout status deployment/modresorts -n modresorts
```

### Rollback

```bash
kubectl rollout undo deployment/modresorts -n modresorts
```

### Viewing Logs

```bash
kubectl logs -f deployment/modresorts -n modresorts
```

## Java Notes

### JVM Settings

The container runs Java 8 on `eclipse-temurin:8-jdk`. The JVM is tuned for containerized environments:

- `JAVA_OPTS`: `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`
- `-Xmx512m` — maximum heap size of 512 MB
- `-Xms256m` — initial heap size of 256 MB
- `-XX:+UseContainerSupport` — enables container-aware memory limits
- `-XX:MaxRAMPercentage=75.0` — uses 75% of the container's memory limit for the heap

These settings align with the Kubernetes resource limits (512Mi request, 1Gi limit).

### Servlet Container

The application is packaged as a WAR file and runs on Apache Tomcat 8.5. The Tomcat distribution is downloaded during the Docker build stage and included in the final image alongside the application WAR file.

### Health Endpoint

The application exposes a `/health` endpoint at `/health` (mapped via `HealthServlet`). It returns a JSON response `{"status":"UP"}` with HTTP 200, and is used by Kubernetes liveness and readiness probes.

### Spring Profiles

This application does not use Spring Boot or Spring profiles. It is a standard Java Servlet application deployed as a WAR file on Apache Tomcat.

## Troubleshooting

### Pod Failures

Check pod status and logs:

```bash
kubectl get pods -n modresorts
kubectl describe pod <pod-name> -n modresorts
kubectl logs <pod-name> -n modresorts
```

### Service Issues

Verify the Service is routing traffic:

```bash
kubectl get svc -n modresorts
kubectl describe svc modresorts-service -n modresorts
```

### Ingress Problems

Check the Ingress status and the AWS Load Balancer Controller:

```bash
kubectl get ingress -n modresorts
kubectl describe ingress modresorts-ingress -n modresorts
```

Ensure the AWS Load Balancer Controller is installed and the IAM OIDC provider is configured for the EKS cluster.
