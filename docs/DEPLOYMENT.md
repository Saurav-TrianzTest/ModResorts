# ModResorts - Deployment Guide (AWS EKS)

## Overview

This guide covers building, containerizing, and deploying the **ModResorts** Java web application (WAR) to **AWS Elastic Kubernetes Service (EKS)**.

- **Application**: ModResorts (modresorts-2.0.0.war)
- **Framework**: Java EE 7 / Servlet 3.1
- **Build Tool**: Maven
- **Java Version**: 8
- **Package Type**: WAR
- **Application Port**: 9080
- **Health Endpoint**: `/health`

---

## Prerequisites

### Local Development
- Docker Desktop 20.x or later
- Java 8 JDK
- Apache Maven 3.6+

### AWS EKS Deployment
- AWS CLI v2 configured (`aws configure`)
- `kubectl` v1.24+
- `eksctl` (optional, for cluster creation)
- IAM permissions: `eks:*`, `ecr:*`, `ec2:*`
- An existing EKS cluster with AWS Load Balancer Controller installed

---

## Project Structure

```
TestMcont/
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── pom.xml
├── src/
│   └── main/java/com/acme/modres/
├── WebContent/
├── kubernetes/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── scripts/
│   ├── build-push.sh
│   ├── build-push.bat
│   ├── deploy-image.sh
│   └── deploy-image.bat
└── docs/
    └── DEPLOYMENT.md
```

---

## 1. Local Development with Docker Compose

### Build and Run Locally

```bash
# Build and start the application
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f modresorts

# Stop the application
docker-compose down
```

### Access the Application

- Application: http://localhost:9080/resorts
- Health Check: http://localhost:9080/health

### Environment Variables (docker-compose)

| Variable | Description | Default |
|---|---|---|
| `WEATHER_API_KEY` | API key for weather data (wunderground.com) | *(empty - uses mock data)* |
| `SERVER_DISPLAY_NAME` | Display name for the server | `modresorts-container` |
| `SERVER_FULL_NAME` | Full server name | `modresorts-container-01` |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m ...` |
| `TZ` | Timezone | `UTC` |

---

## 2. Build and Push Docker Image

### Linux / macOS

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

### Windows

```cmd
scripts\build-push.bat
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type: **AWS ECR** or **Docker Hub**
3. Provide registry credentials

**AWS ECR Example:**
```
Enter image tag: v2.0.0
Select registry: 1 (AWS ECR)
AWS Region: us-east-1
AWS Account ID: 123456789012
```
Resulting image: `123456789012.dkr.ecr.us-east-1.amazonaws.com/modresorts:v2.0.0`

**Docker Hub Example:**
```
Enter image tag: v2.0.0
Select registry: 2 (Docker Hub)
Docker Hub username: myuser
```
Resulting image: `myuser/modresorts:v2.0.0`

---

## 3. AWS EKS Prerequisites

### Install Required Tools

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# eksctl (optional)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

### Configure AWS CLI

```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region name: us-east-1
# Default output format: json
```

### Create EKS Cluster (if needed)

```bash
eksctl create cluster \
  --name modresorts-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

### Install AWS Load Balancer Controller

```bash
# Associate OIDC provider
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster modresorts-cluster \
  --approve

# Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=modresorts-cluster \
  --set serviceAccount.create=true
```

---

## 4. Deploy to AWS EKS

### Linux / macOS

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

### Windows

```cmd
scripts\deploy-image.bat
```

The script will prompt for:
- AWS Region
- EKS Cluster Name
- Full Docker image URI (with tag)
- Optional environment variables (`WEATHER_API_KEY`, `SERVER_DISPLAY_NAME`, `SERVER_FULL_NAME`)

### Manual Deployment

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name modresorts-cluster

# Update image URI in deployment.yaml
sed -i 's|{{IMAGE_URI}}|123456789012.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest|g' kubernetes/deployment.yaml

# Apply manifests
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Monitor rollout
kubectl rollout status deployment/modresorts -n modresorts
```

---

## 5. Kubernetes Manifest Descriptions

| File | Description |
|---|---|
| `namespace.yaml` | Creates the `modresorts` namespace |
| `deployment.yaml` | Deploys 2 replicas with liveness/readiness probes on `/health` |
| `service.yaml` | ClusterIP service exposing port 80 → 9080 |
| `ingress.yaml` | AWS ALB Ingress routing `modresorts.example.com` to the service |

### Resource Limits

| Resource | Request | Limit |
|---|---|---|
| CPU | 250m | 500m |
| Memory | 512Mi | 1Gi |

### Health Probes

- **Liveness Probe**: `GET /health` — initial delay 60s, period 30s
- **Readiness Probe**: `GET /health` — initial delay 30s, period 15s

---

## 6. Verify Deployment

```bash
# Check pods
kubectl get pods -n modresorts

# Check services
kubectl get svc -n modresorts

# Check ingress (wait for ALB to provision)
kubectl get ingress -n modresorts

# View application logs
kubectl logs -f deployment/modresorts -n modresorts

# Describe a pod for troubleshooting
kubectl describe pod <pod-name> -n modresorts
```

---

## 7. Scaling and Management

### Manual Scaling

```bash
kubectl scale deployment modresorts --replicas=3 -n modresorts
```

### Horizontal Pod Autoscaler (HPA)

```bash
kubectl autoscale deployment modresorts \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n modresorts
```

### Rolling Update

```bash
# Update image
kubectl set image deployment/modresorts modresorts=<new-image-uri> -n modresorts

# Monitor rollout
kubectl rollout status deployment/modresorts -n modresorts
```

### Rollback

```bash
kubectl rollout undo deployment/modresorts -n modresorts

# Rollback to specific revision
kubectl rollout undo deployment/modresorts --to-revision=2 -n modresorts

# View rollout history
kubectl rollout history deployment/modresorts -n modresorts
```

---

## 8. Troubleshooting

### Pod Not Starting

```bash
kubectl describe pod <pod-name> -n modresorts
kubectl logs <pod-name> -n modresorts --previous
```

### Image Pull Errors

```bash
# Verify ECR credentials
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

# Check image exists
aws ecr list-images --repository-name modresorts --region us-east-1
```

### Health Check Failures

```bash
# Test health endpoint locally
docker run --rm -p 9080:9080 <image-uri>
# Then: curl http://localhost:9080/health

# Check pod health
kubectl exec -it <pod-name> -n modresorts -- sh
```

### Ingress Not Getting External IP

```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify ingress annotations
kubectl describe ingress modresorts-ingress -n modresorts
```

---

## 9. Configuration Management

### Environment Variables

Update environment variables in `kubernetes/deployment.yaml` under `spec.containers[].env`:

```yaml
env:
  - name: WEATHER_API_KEY
    value: "your-api-key"
```

For sensitive values, use Kubernetes Secrets:

```bash
kubectl create secret generic modresorts-secrets \
  --from-literal=WEATHER_API_KEY=your-api-key \
  -n modresorts
```

Then reference in deployment.yaml:

```yaml
env:
  - name: WEATHER_API_KEY
    valueFrom:
      secretKeyRef:
        name: modresorts-secrets
        key: WEATHER_API_KEY
```

---

## 10. Security Considerations

- The container runs as a **non-root user** (`appuser`)
- Sensitive values (API keys) should be stored in **Kubernetes Secrets** or **AWS Secrets Manager**
- Use **IAM Roles for Service Accounts (IRSA)** for AWS resource access
- Enable **network policies** to restrict pod-to-pod communication
- Regularly update base images (`eclipse-temurin:8-jdk`) for security patches
- The application security constraints in `web.xml` are commented out for demo purposes — enable them in production

---

## 11. Java-Specific Notes

- **JVM Memory**: Container-aware JVM flags are set: `-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`
- **Heap Size**: `-Xmx512m -Xms256m` (adjust based on container memory limits)
- **Startup Time**: Java 8 applications may take 30-60 seconds to start; liveness probe has a 60s initial delay
- **Weather API**: Set `WEATHER_API_KEY` environment variable to enable real-time weather data; without it, the app uses static mock data
- **Timezone**: Set to `UTC` by default via `TZ` environment variable
- **Logging**: Application uses `java.util.logging`; configure log levels via JVM system properties if needed

---

*Generated for ModResorts v2.0.0 — AWS EKS Deployment*
