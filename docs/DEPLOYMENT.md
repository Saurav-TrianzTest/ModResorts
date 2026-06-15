# ModResorts - Deployment Guide (AWS EKS)

## Overview

This guide covers building, containerizing, and deploying the **ModResorts** Java web application (WAR) to **AWS Elastic Kubernetes Service (EKS)**.

- **Application**: ModResorts (`com.acme.modres:modresorts:2.0.0`)
- **Build Tool**: Maven
- **Java Version**: 8
- **Package Type**: WAR
- **Context Root**: `/resorts`
- **Application Port**: 8080
- **Health Endpoint**: `/resorts/health`
- **Target Platform**: AWS EKS

---

## Prerequisites

### Local Development
- Docker Desktop 20.10+
- Java 8 JDK
- Apache Maven 3.9+

### AWS EKS Deployment
- AWS CLI v2 (`aws --version`)
- `kubectl` 1.27+ (`kubectl version --client`)
- `eksctl` (optional, for cluster creation)
- AWS IAM permissions:
  - `ecr:*` (ECR push/pull)
  - `eks:DescribeCluster`, `eks:UpdateKubeconfig`
  - `elasticloadbalancing:*` (for ALB Ingress Controller)

---

## Project Structure

```
SGPMonoStudio/
├── Dockerfile                  # Multi-stage Docker build
├── docker-compose.yml          # Local development compose
├── .dockerignore               # Docker build exclusions
├── pom.xml                     # Maven build descriptor
├── src/                        # Java source code
├── WebContent/                 # Web resources (HTML, JSP, JS, CSS)
├── kubernetes/
│   ├── namespace.yaml          # Kubernetes namespace
│   ├── deployment.yaml         # Application deployment
│   ├── service.yaml            # ClusterIP service
│   └── ingress.yaml            # AWS ALB ingress
├── scripts/
│   ├── build-push.sh           # Linux/macOS build & push
│   ├── build-push.bat          # Windows build & push
│   ├── deploy-image.sh         # Linux/macOS EKS deploy
│   └── deploy-image.bat        # Windows EKS deploy
└── docs/
    └── DEPLOYMENT.md           # This file
```

---

## Local Development with Docker Compose

### 1. Build and Start

```bash
# From project root
docker-compose up --build
```

### 2. Access the Application

- Application: http://localhost:8080/resorts/
- Health Check: http://localhost:8080/resorts/health

### 3. Environment Variables (Local)

Create a `.env` file in the project root:

```env
WEATHER_API_KEY=your_weather_api_key_here
SERVER_DISPLAY_NAME=modresorts-server
SERVER_FULL_NAME=modresorts-server/default
JNDI_PROVIDER_URL=
DB_URL=jdbc:postgresql://your-db-host:5432/modresorts
DB_USERNAME=dbuser
DB_PASSWORD=dbpassword
```

### 4. Stop

```bash
docker-compose down
```

---

## Build and Push Docker Image

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
1. Enter an image tag (defaults to `latest`)
2. Select registry type (AWS ECR or Docker Hub)
3. Provide registry credentials

**AWS ECR Example:**
```
Enter image tag: v2.0.0
Select registry: 1 (AWS ECR)
AWS Region: us-east-1
AWS Account ID: 123456789012
```

The script automatically creates the ECR repository if it does not exist.

---

## AWS EKS Deployment

### Step 1: Configure AWS CLI

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region, Output format
```

### Step 2: Create or Connect to EKS Cluster

**Create a new cluster (if needed):**
```bash
eksctl create cluster \
  --name modresorts-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4
```

**Connect to existing cluster:**
```bash
aws eks update-kubeconfig --region us-east-1 --name modresorts-cluster
kubectl cluster-info
```

### Step 3: Install AWS Load Balancer Controller (for Ingress)

```bash
# Install cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=modresorts-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 4: Deploy to EKS

**Linux / macOS:**
```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

**Windows:**
```cmd
scripts\deploy-image.bat
```

The script will prompt for:
- AWS Region
- EKS Cluster Name
- Full Docker image URI (e.g., `123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:v2.0.0`)
- Optional environment variable values

### Step 5: Verify Deployment

```bash
# Check pods
kubectl get pods -n modresorts

# Check services
kubectl get svc -n modresorts

# Check ingress (wait for ALB hostname)
kubectl get ingress -n modresorts

# View logs
kubectl logs -f deployment/modresorts -n modresorts
```

---

## Kubernetes Manifest Details

### namespace.yaml
Creates the `modresorts` namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (high availability)
- **Image**: Placeholder `{{IMAGE_URI}}` replaced at deploy time
- **Resources**: 250m CPU / 512Mi memory (requests), 500m CPU / 1Gi memory (limits)
- **Liveness Probe**: HTTP GET `/resorts/health` — starts after 60s, checks every 30s
- **Readiness Probe**: HTTP GET `/resorts/health` — starts after 30s, checks every 15s
- **JVM Options**: `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`

### service.yaml
- **Type**: ClusterIP (internal cluster access)
- **Port**: 80 → 8080 (container port)

### ingress.yaml
- **Class**: AWS ALB (Application Load Balancer)
- **Scheme**: internet-facing
- **Health Check Path**: `/resorts/health`
- **Host**: `modresorts.example.com` (update to your actual domain)

---

## Configuration Management

### Environment Variables Reference

| Variable | Description | Default |
|---|---|---|
| `WEATHER_API_KEY` | API key for weather data (wunderground.com) | *(empty)* |
| `SERVER_DISPLAY_NAME` | Server display name for JMX/logging | `modresorts-server` |
| `SERVER_FULL_NAME` | Full server name for JMX/logging | `modresorts-server/default` |
| `JNDI_PROVIDER_URL` | JNDI provider URL (optional) | *(empty)* |
| `DB_URL` | JDBC database URL | *(empty)* |
| `DB_USERNAME` | Database username | *(empty)* |
| `DB_PASSWORD` | Database password | *(empty)* |
| `JAVA_OPTS` | JVM options | See Dockerfile |
| `TZ` | Timezone | `UTC` |

### Using Kubernetes Secrets for Sensitive Values

```bash
kubectl create secret generic modresorts-secrets \
  --from-literal=WEATHER_API_KEY=your_api_key \
  --from-literal=DB_PASSWORD=your_db_password \
  -n modresorts
```

Then reference in `deployment.yaml`:
```yaml
env:
  - name: WEATHER_API_KEY
    valueFrom:
      secretKeyRef:
        name: modresorts-secrets
        key: WEATHER_API_KEY
```

---

## Scaling and Management

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
kubectl set image deployment/modresorts \
  modresorts=123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:v2.1.0 \
  -n modresorts

# Monitor rollout
kubectl rollout status deployment/modresorts -n modresorts
```

### Rollback

```bash
kubectl rollout undo deployment/modresorts -n modresorts
# Or to a specific revision:
kubectl rollout undo deployment/modresorts --to-revision=2 -n modresorts
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Describe pod for events
kubectl describe pod -l app=modresorts -n modresorts

# Check logs
kubectl logs -l app=modresorts -n modresorts --previous
```

### Health Check Failing

```bash
# Test health endpoint from within cluster
kubectl exec -it deployment/modresorts -n modresorts -- \
  wget -qO- http://localhost:8080/resorts/health
```

### Ingress Not Getting Hostname

```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify ingress annotations
kubectl describe ingress modresorts-ingress -n modresorts
```

### Image Pull Errors

```bash
# Verify ECR credentials
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

# Check image exists
aws ecr describe-images --repository-name modresorts --region us-east-1
```

### OOMKilled (Out of Memory)

Increase memory limits in `kubernetes/deployment.yaml`:
```yaml
resources:
  limits:
    memory: "2Gi"
```
Or adjust JVM heap:
```yaml
- name: JAVA_OPTS
  value: "-Xmx1g -Xms512m -XX:+UseContainerSupport"
```

---

## Security Considerations

1. **Non-root container**: The Dockerfile creates and uses a non-root `appuser` account.
2. **Secrets management**: Use Kubernetes Secrets or AWS Secrets Manager for sensitive values — never hardcode credentials.
3. **Network policies**: Consider adding Kubernetes NetworkPolicy to restrict pod-to-pod communication.
4. **Image scanning**: Enable ECR image scanning on push for vulnerability detection.
5. **RBAC**: Apply least-privilege IAM roles for EKS node groups and service accounts.
6. **TLS**: Configure HTTPS on the ALB ingress using AWS Certificate Manager (ACM):
   ```yaml
   annotations:
     alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789:certificate/xxx
     alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
   ```

---

## Java-Specific Notes

- **Java 8 WAR**: This application is packaged as a WAR and runs on an embedded servlet container.
- **JVM Container Support**: `-XX:+UseContainerSupport` ensures the JVM respects container memory limits (Java 8u191+).
- **MaxRAMPercentage**: Set to 75% to leave headroom for the OS and non-heap memory.
- **Startup Time**: JVM startup may take 30–60 seconds; liveness probe `initialDelaySeconds` is set to 60s accordingly.
- **Graceful Shutdown**: `terminationGracePeriodSeconds: 30` allows in-flight requests to complete before pod termination.
- **Weather API**: Set `WEATHER_API_KEY` environment variable to enable real-time weather data from wunderground.com. Without it, the application uses static default weather data.
