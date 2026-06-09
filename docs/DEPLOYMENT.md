# ModResorts - Deployment Guide (AWS EKS)

## Overview

This guide covers building, containerizing, and deploying the **ModResorts** Java web application to **AWS Elastic Kubernetes Service (EKS)**.

- **Application**: ModResorts (modresorts-2.0.0.war)
- **Framework**: Java EE / Servlet 3.1 (Spring MVC + JAX-RS)
- **Build Tool**: Maven 3.x
- **Java Version**: Java 8
- **Package Type**: WAR (deployed on Apache Tomcat 9)
- **Context Root**: `/resorts`
- **Application Port**: `8080`
- **Health Endpoint**: `GET /resorts/health`

---

## Prerequisites

### Local Development
| Tool | Version | Purpose |
|------|---------|---------|
| Java JDK | 8+ | Build and run locally |
| Maven | 3.6+ | Build tool |
| Docker | 20.10+ | Container build and run |
| Docker Compose | 2.x | Local multi-container orchestration |

### AWS EKS Deployment
| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | 2.x | AWS authentication and ECR access |
| kubectl | 1.27+ | Kubernetes cluster management |
| eksctl | 0.150+ | EKS cluster creation (optional) |

### IAM Permissions Required
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
- `ecr:CreateRepository`
- `eks:DescribeCluster`
- `eks:UpdateKubeconfig`

---

## Project Structure

```
TMCont/
├── Dockerfile                  # Multi-stage Docker build
├── docker-compose.yml          # Local development compose
├── .dockerignore               # Docker build exclusions
├── pom.xml                     # Maven build descriptor
├── src/
│   └── main/
│       ├── java/com/acme/modres/   # Application source
│       └── resources/              # JSON config files
├── WebContent/                 # Static web assets + WEB-INF
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

## Local Development Setup

### 1. Build with Maven

```bash
mvn clean package -DskipTests
```

The WAR file will be generated at: `target/modresorts-2.0.0.war`

### 2. Build Docker Image Locally

```bash
docker build -t modresorts:latest .
```

### 3. Run with Docker Compose

```bash
# Optional: set environment variables
export WEATHER_API_KEY=your_api_key_here

docker-compose up -d
```

Access the application at: `http://localhost:8080/resorts/`

### 4. Verify Health

```bash
curl http://localhost:8080/resorts/health
# Expected: {"status":"UP","application":"modresorts"}
```

### 5. Stop Local Environment

```bash
docker-compose down
```

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WEATHER_API_KEY` | No | _(empty)_ | Weather Underground API key. If not set, default static weather data is used. |
| `SERVER_DISPLAY_NAME` | No | _(empty)_ | Server display name for JMX/monitoring |
| `SERVER_FULL_NAME` | No | _(empty)_ | Server full name for JMX/monitoring |
| `JAVA_OPTS` | No | `-Xms256m -Xmx512m ...` | JVM startup options |
| `TZ` | No | `UTC` | Container timezone |
| `SPRING_PROFILES_ACTIVE` | No | `docker` | Active Spring profile |

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
1. Enter an image tag (default: `latest`)
2. Select registry type: **AWS ECR** or **Docker Hub**
3. Provide registry credentials

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
```

### Step 3: Install AWS Load Balancer Controller (for Ingress)

```bash
# Add EKS Helm chart repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=modresorts-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 4: Build and Push Image to ECR

```bash
./scripts/build-push.sh
# Select option 1 (AWS ECR)
# Enter your AWS Region and Account ID
```

### Step 5: Deploy to EKS

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will prompt for:
- AWS Region
- EKS Cluster Name
- Full Docker image URI (from ECR)
- Optional environment variables (WEATHER_API_KEY, etc.)

### Step 6: Verify Deployment

```bash
# Check pods are running
kubectl get pods -n modresorts

# Check service
kubectl get svc -n modresorts

# Check ingress (ALB hostname)
kubectl get ingress -n modresorts

# View pod logs
kubectl logs -l app=modresorts -n modresorts --tail=100

# Describe deployment
kubectl describe deployment modresorts -n modresorts
```

### Step 7: Access the Application

```bash
# Get ALB hostname
ALB_HOST=$(kubectl get ingress modresorts-ingress -n modresorts \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://${ALB_HOST}/resorts/"
echo "Health Check:    http://${ALB_HOST}/resorts/health"
```

---

## Kubernetes Manifest Details

### namespace.yaml
Creates the `modresorts` namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (high availability)
- **Image**: Pulled from `{{IMAGE_URI}}` (replaced at deploy time)
- **Resources**: 250m CPU / 512Mi memory (requests); 500m CPU / 1Gi memory (limits)
- **Liveness Probe**: `GET /resorts/health` — restarts container if unhealthy
- **Readiness Probe**: `GET /resorts/health` — removes from load balancer if not ready
- **Security**: Runs as non-root user (UID 1000)

### service.yaml
- **Type**: ClusterIP (internal cluster access)
- **Port**: 80 → 8080 (container port)

### ingress.yaml
- **Controller**: AWS ALB (Application Load Balancer)
- **Scheme**: internet-facing
- **Health Check Path**: `/resorts/health`
- **Host**: `modresorts.example.com` (update to your actual domain)

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
  modresorts=<new-image-uri> \
  -n modresorts

# Monitor rollout
kubectl rollout status deployment/modresorts -n modresorts
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/modresorts -n modresorts

# Rollback to specific revision
kubectl rollout history deployment/modresorts -n modresorts
kubectl rollout undo deployment/modresorts --to-revision=2 -n modresorts
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n modresorts

# Describe pod for events
kubectl describe pod <pod-name> -n modresorts

# Check logs
kubectl logs <pod-name> -n modresorts
kubectl logs <pod-name> -n modresorts --previous  # previous container logs
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|---------|
| `ImagePullBackOff` | Cannot pull image from ECR | Verify ECR permissions and image URI |
| `CrashLoopBackOff` | Application crash on startup | Check logs; verify JAVA_OPTS memory settings |
| `OOMKilled` | Out of memory | Increase memory limits in deployment.yaml |
| Liveness probe failing | App not responding on `/resorts/health` | Check Tomcat startup; increase `initialDelaySeconds` |
| Ingress not getting hostname | ALB controller not installed | Install AWS Load Balancer Controller |

### Health Check Debugging

```bash
# Port-forward to test locally
kubectl port-forward deployment/modresorts 8080:8080 -n modresorts

# Test health endpoint
curl http://localhost:8080/resorts/health
```

### Resource Issues

```bash
# Check resource usage
kubectl top pods -n modresorts
kubectl top nodes
```

---

## Security Considerations

1. **Non-root user**: Container runs as UID 1000 (appuser)
2. **Read-only config**: Config volume mounted as read-only (`:ro`)
3. **Secrets management**: Use Kubernetes Secrets or AWS Secrets Manager for sensitive values like `WEATHER_API_KEY`
4. **Network policies**: Consider adding NetworkPolicy resources to restrict pod-to-pod communication
5. **Image scanning**: Enable ECR image scanning for vulnerability detection
6. **RBAC**: Apply least-privilege IAM roles for EKS node groups

### Using Kubernetes Secrets for API Keys

```bash
# Create secret
kubectl create secret generic modresorts-secrets \
  --from-literal=WEATHER_API_KEY=your_actual_api_key \
  -n modresorts

# Reference in deployment.yaml (update env section):
# env:
#   - name: WEATHER_API_KEY
#     valueFrom:
#       secretKeyRef:
#         name: modresorts-secrets
#         key: WEATHER_API_KEY
```

---

## Java-Specific Configuration Notes

### JVM Memory Settings

The default `JAVA_OPTS` are configured for container-aware JVM:
```
-Xms256m -Xmx512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions
```

- `-XX:+UseContainerSupport`: Enables JVM to respect container memory limits
- `-XX:MaxRAMPercentage=75.0`: JVM uses up to 75% of container memory
- Adjust `JAVA_OPTS` in deployment.yaml if you change memory limits

### Tomcat Configuration

The application runs on **Apache Tomcat 9** with the WAR deployed at context root `/resorts`.

Key endpoints:
- `http://<host>/resorts/` — Application home
- `http://<host>/resorts/health` — Health check (returns `{"status":"UP"}`)
- `http://<host>/resorts/weather?selectedCity=Paris` — Weather API
- `http://<host>/resorts/availability?date=MM/dd/yyyy` — Availability checker

### Weather API

The application supports real-time weather data via Weather Underground API:
- Set `WEATHER_API_KEY` environment variable with a valid API key
- Without the key, the application serves static weather data from JSON files

---

## Cleanup

```bash
# Remove all application resources
kubectl delete namespace modresorts

# Or remove individual resources
kubectl delete -f kubernetes/ingress.yaml
kubectl delete -f kubernetes/service.yaml
kubectl delete -f kubernetes/deployment.yaml
kubectl delete -f kubernetes/namespace.yaml
```
