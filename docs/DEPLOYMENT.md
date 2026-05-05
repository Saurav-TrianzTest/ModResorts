# ModResorts - AWS ECS Fargate Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Architecture](#project-architecture)
4. [Local Development](#local-development)
5. [AWS ECS Fargate Setup](#aws-ecs-fargate-setup)
6. [Building and Pushing Images](#building-and-pushing-images)
7. [Deploying to ECS Fargate](#deploying-to-ecs-fargate)
8. [Configuration Management](#configuration-management)
9. [Monitoring and Logging](#monitoring-and-logging)
10. [Troubleshooting](#troubleshooting)
11. [Security Considerations](#security-considerations)
12. [Scaling and Performance](#scaling-and-performance)

---

## Overview

ModResorts is a Java EE 7 web application packaged as a WAR file. This guide covers containerization and deployment to AWS ECS Fargate, a serverless container orchestration platform.

**Application Details:**
- **Technology**: Java 8, Maven, Java EE 7
- **Package Type**: WAR (deployed on Tomcat 9)
- **Application Port**: 8080
- **Health Endpoints**: `/health`, `/health/live`, `/health/ready`
- **Container Runtime**: Tomcat 9 with JRE 8

---

## Prerequisites

### Required Tools
- **Docker**: Version 20.10 or higher
  ```bash
  docker --version
  ```
- **AWS CLI**: Version 2.x
  ```bash
  aws --version
  ```
- **Maven**: Version 3.6 or higher (for local builds)
  ```bash
  mvn --version
  ```
- **Git**: For version control
  ```bash
  git --version
  ```

### AWS Account Requirements
- Active AWS account with appropriate permissions
- IAM user with permissions for:
  - ECS (Elastic Container Service)
  - ECR (Elastic Container Registry)
  - EC2 (for VPC, subnets, security groups)
  - CloudWatch Logs
  - IAM (for role creation)
  - Elastic Load Balancing (optional)

### AWS CLI Configuration
Configure AWS CLI with your credentials:
```bash
aws configure
```
Provide:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

---

## Project Architecture

### Application Structure
```
ModResorts/
├── src/
│   └── main/
│       ├── java/
│       │   └── com/acme/modres/
│       │       ├── WelcomeServlet.java
│       │       ├── HealthCheckServlet.java
│       │       ├── WeatherServlet.java
│       │       └── ...
│       └── resources/
├── WebContent/
│   └── WEB-INF/
│       └── web.xml
├── pom.xml
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── ecs/
│   ├── task-definition.json
│   └── service-definition.json
├── scripts/
│   ├── build-push.sh
│   ├── build-push.bat
│   ├── deploy-image.sh
│   └── deploy-image.bat
└── docs/
    └── DEPLOYMENT.md
```

### Container Architecture
```
┌─────────────────────────────────────┐
│   Builder Stage (Maven + JDK 8)    │
│   - Download dependencies           │
│   - Compile Java code               │
│   - Package WAR file                │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   Runtime Stage (Tomcat 9 + JRE 8) │
│   - Copy WAR from builder           │
│   - Configure Tomcat                │
│   - Set JVM options                 │
│   - Expose port 8080                │
└─────────────────────────────────────┘
```

### AWS ECS Fargate Architecture
```
┌──────────────────────────────────────────────────────────┐
│                    Application Load Balancer             │
│                    (Optional - Port 80)                   │
└────────────────────┬─────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼────────┐    ┌────────▼────────┐
│  ECS Task 1     │    │  ECS Task 2     │
│  (Fargate)      │    │  (Fargate)      │
│                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │
│  │ Container │  │    │  │ Container │  │
│  │ ModResorts│  │    │  │ ModResorts│  │
│  │ Port 8080 │  │    │  │ Port 8080 │  │
│  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │   CloudWatch Logs     │
         │   /ecs/modresorts     │
         └───────────────────────┘
```

---

## Local Development

### Building Locally with Maven
```bash
# Navigate to project directory
cd ModResorts

# Clean and build
mvn clean package

# The WAR file will be in target/modresorts-2.0.0.war
```

### Building with Docker
```bash
# Build the Docker image
docker build -t modresorts:latest .

# Verify the image
docker images | grep modresorts
```

### Running Locally with Docker
```bash
# Run the container
docker run -d \
  --name modresorts \
  -p 8080:8080 \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  modresorts:latest

# Check logs
docker logs -f modresorts

# Test the application
curl http://localhost:8080/health
```

### Running with Docker Compose
```bash
# Start the application
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the application
docker-compose down
```

### Testing Health Endpoints
```bash
# Basic health check
curl http://localhost:8080/health

# Liveness probe
curl http://localhost:8080/health/live

# Readiness probe
curl http://localhost:8080/health/ready
```

---

## AWS ECS Fargate Setup

### Step 1: Create VPC and Networking (if not exists)

#### Create VPC
```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=modresorts-vpc}]'
```

#### Create Subnets (at least 2 in different AZs)
```bash
# Subnet 1
aws ec2 create-subnet \
  --vpc-id vpc-xxxxx \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=modresorts-subnet-1}]'

# Subnet 2
aws ec2 create-subnet \
  --vpc-id vpc-xxxxx \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=modresorts-subnet-2}]'
```

#### Create Internet Gateway
```bash
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=modresorts-igw}]'

aws ec2 attach-internet-gateway \
  --vpc-id vpc-xxxxx \
  --internet-gateway-id igw-xxxxx
```

#### Create Security Group
```bash
aws ec2 create-security-group \
  --group-name modresorts-sg \
  --description "Security group for ModResorts ECS tasks" \
  --vpc-id vpc-xxxxx

# Allow inbound traffic on port 8080
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0

# Allow inbound traffic on port 80 (for ALB)
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

### Step 2: Create IAM Roles

#### ECS Task Execution Role
This role allows ECS to pull images from ECR and write logs to CloudWatch.

```bash
# Create trust policy file
cat > ecs-task-execution-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach AWS managed policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

#### ECS Task Role (Optional)
This role grants permissions to the application running in the container.

```bash
# Create the role
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach policies as needed (e.g., S3, DynamoDB access)
```

### Step 3: Create ECR Repository
```bash
aws ecr create-repository \
  --repository-name modresorts \
  --region us-east-1
```

### Step 4: Create CloudWatch Log Group
```bash
aws logs create-log-group \
  --log-group-name /ecs/modresorts \
  --region us-east-1
```

---

## Building and Pushing Images

### Using the Build Script (Linux/macOS)

```bash
# Make the script executable
chmod +x scripts/build-push.sh

# Run the script
./scripts/build-push.sh
```

The script will:
1. Prompt for registry selection (AWS ECR or Docker Hub)
2. Authenticate with the selected registry
3. Build the Docker image
4. Push the image to the registry

### Using the Build Script (Windows)

```cmd
# Run the script
scripts\build-push.bat
```

### Manual Build and Push (AWS ECR)

```bash
# Set variables
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO=modresorts
IMAGE_TAG=latest

# Authenticate with ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build the image
docker build -t $ECR_REPO:$IMAGE_TAG .

# Tag the image
docker tag $ECR_REPO:$IMAGE_TAG \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

# Push the image
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG
```

---

## Deploying to ECS Fargate

### Using the Deployment Script (Linux/macOS)

```bash
# Make the script executable
chmod +x scripts/deploy-image.sh

# Run the script
./scripts/deploy-image.sh
```

The script will:
1. Prompt for AWS region and cluster name
2. Create ECS cluster (if not exists)
3. Prompt for network configuration (VPC, subnets, security group)
4. Prompt for Docker image URI
5. Optionally create Application Load Balancer and Target Group
6. Register ECS task definition
7. Create or update ECS service
8. Wait for service to stabilize
9. Display deployment summary

### Using the Deployment Script (Windows)

```cmd
# Run the script
scripts\deploy-image.bat
```

### Manual Deployment

#### 1. Register Task Definition
```bash
# Update placeholders in task-definition.json
sed -i "s|{{IMAGE_URI}}|123456789.dkr.ecr.us-east-1.amazonaws.com/modresorts:latest|g" ecs/task-definition.json
sed -i "s|{{AWS_REGION}}|us-east-1|g" ecs/task-definition.json
sed -i "s|{{ACCOUNT_ID}}|123456789|g" ecs/task-definition.json

# Register the task definition
aws ecs register-task-definition \
  --cli-input-json file://ecs/task-definition.json \
  --region us-east-1
```

#### 2. Create ECS Service
```bash
# Update placeholders in service-definition.json
sed -i "s|{{CLUSTER_NAME}}|modresorts-cluster|g" ecs/service-definition.json
sed -i "s|{{SUBNET_1}}|subnet-xxxxx|g" ecs/service-definition.json
sed -i "s|{{SUBNET_2}}|subnet-yyyyy|g" ecs/service-definition.json
sed -i "s|{{SECURITY_GROUP}}|sg-xxxxx|g" ecs/service-definition.json
sed -i "s|{{TARGET_GROUP_ARN}}|arn:aws:elasticloadbalancing:...|g" ecs/service-definition.json

# Create the service
aws ecs create-service \
  --cli-input-json file://ecs/service-definition.json \
  --region us-east-1
```

#### 3. Wait for Service Stability
```bash
aws ecs wait services-stable \
  --cluster modresorts-cluster \
  --services modresorts-service \
  --region us-east-1
```

---

## Configuration Management

### Environment Variables

Environment variables are configured in the ECS task definition (`ecs/task-definition.json`):

```json
"environment": [
  {
    "name": "JAVA_OPTS",
    "value": "-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
  },
  {
    "name": "CATALINA_OPTS",
    "value": "-Duser.timezone=UTC"
  },
  {
    "name": "APP_ENV",
    "value": "production"
  },
  {
    "name": "LOG_LEVEL",
    "value": "INFO"
  }
]
```

### JVM Tuning

The application uses the following JVM settings optimized for containers:

- **Heap Size**: `-Xmx512m -Xms256m` (adjust based on task memory)
- **Container Support**: `-XX:+UseContainerSupport` (respects container memory limits)
- **RAM Percentage**: `-XX:MaxRAMPercentage=75.0` (uses 75% of container memory)
- **Timezone**: `-Duser.timezone=UTC`

### Fargate CPU and Memory Combinations

Valid combinations for ECS Fargate:

| CPU (vCPU) | Memory (MB) |
|------------|-------------|
| 256 (.25)  | 512, 1024, 2048 |
| 512 (.5)   | 1024, 2048, 3072, 4096 |
| 1024 (1)   | 2048, 3072, 4096, 5120, 6144, 7168, 8192 |
| 2048 (2)   | 4096-16384 (increments of 1024) |
| 4096 (4)   | 8192-30720 (increments of 1024) |

**Default Configuration**: CPU: 512, Memory: 1024

---

## Monitoring and Logging

### CloudWatch Logs

Logs are automatically sent to CloudWatch Logs:

```bash
# View logs in real-time
aws logs tail /ecs/modresorts --follow --region us-east-1

# View logs for specific time range
aws logs filter-log-events \
  --log-group-name /ecs/modresorts \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --region us-east-1
```

### ECS Service Metrics

Monitor service health:

```bash
# Describe service
aws ecs describe-services \
  --cluster modresorts-cluster \
  --services modresorts-service \
  --region us-east-1

# List running tasks
aws ecs list-tasks \
  --cluster modresorts-cluster \
  --service-name modresorts-service \
  --region us-east-1

# Describe task
aws ecs describe-tasks \
  --cluster modresorts-cluster \
  --tasks task-id \
  --region us-east-1
```

### CloudWatch Metrics

Key metrics to monitor:
- **CPUUtilization**: Container CPU usage
- **MemoryUtilization**: Container memory usage
- **TargetResponseTime**: ALB target response time
- **HealthyHostCount**: Number of healthy targets
- **UnHealthyHostCount**: Number of unhealthy targets

### Application Health Checks

The application provides three health endpoints:

1. **Basic Health**: `GET /health`
   - Returns application status and memory information
   
2. **Liveness Probe**: `GET /health/live`
   - Checks if the application is running
   
3. **Readiness Probe**: `GET /health/ready`
   - Checks if the application is ready to serve traffic

---

## Troubleshooting

### Common Issues

#### 1. Task Fails to Start

**Symptoms**: Tasks transition from PENDING to STOPPED

**Possible Causes**:
- Invalid CPU/memory combination
- Image pull errors (ECR permissions)
- Invalid task definition

**Solutions**:
```bash
# Check task stopped reason
aws ecs describe-tasks \
  --cluster modresorts-cluster \
  --tasks task-id \
  --region us-east-1 \
  --query 'tasks[0].stoppedReason'

# Check CloudWatch logs for errors
aws logs tail /ecs/modresorts --follow --region us-east-1

# Verify task execution role has ECR permissions
aws iam get-role --role-name ecsTaskExecutionRole
```

#### 2. Container Health Check Failures

**Symptoms**: Tasks marked as unhealthy and replaced

**Possible Causes**:
- Application not starting in time
- Health endpoint not responding
- Incorrect health check configuration

**Solutions**:
```bash
# Increase startPeriod in task definition
"healthCheck": {
  "startPeriod": 120  # Increase from 60 to 120 seconds
}

# Check application logs
aws logs tail /ecs/modresorts --follow --region us-east-1

# Test health endpoint from within container
aws ecs execute-command \
  --cluster modresorts-cluster \
  --task task-id \
  --container modresorts \
  --interactive \
  --command "/bin/sh"
```

#### 3. Network Connectivity Issues

**Symptoms**: Cannot access application, tasks cannot pull images

**Possible Causes**:
- Security group rules
- Subnet routing
- No internet gateway

**Solutions**:
```bash
# Verify security group allows inbound traffic
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check subnet route table
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxxxx"

# Ensure subnets have route to internet gateway
aws ec2 create-route \
  --route-table-id rtb-xxxxx \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-xxxxx
```

#### 4. Out of Memory Errors

**Symptoms**: Tasks crash with OOM errors

**Solutions**:
```bash
# Increase task memory in task definition
"memory": "2048"  # Increase from 1024 to 2048

# Adjust JVM heap size
"JAVA_OPTS": "-Xmx1536m -Xms512m"  # Use 75% of 2048MB

# Monitor memory usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=modresorts-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

#### 5. Image Pull Errors

**Symptoms**: "CannotPullContainerError" in task stopped reason

**Solutions**:
```bash
# Verify ECR repository exists
aws ecr describe-repositories --repository-names modresorts

# Check task execution role has ECR permissions
aws iam list-attached-role-policies --role-name ecsTaskExecutionRole

# Verify image exists in ECR
aws ecr list-images --repository-name modresorts

# Test ECR authentication
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com
```

### Debugging Commands

```bash
# View service events
aws ecs describe-services \
  --cluster modresorts-cluster \
  --services modresorts-service \
  --region us-east-1 \
  --query 'services[0].events[0:10]'

# View task definition
aws ecs describe-task-definition \
  --task-definition modresorts-task \
  --region us-east-1

# View container logs
aws logs get-log-events \
  --log-group-name /ecs/modresorts \
  --log-stream-name ecs/modresorts/task-id \
  --region us-east-1

# Execute command in running container (requires ECS Exec enabled)
aws ecs execute-command \
  --cluster modresorts-cluster \
  --task task-id \
  --container modresorts \
  --interactive \
  --command "/bin/bash"
```

---

## Security Considerations

### Container Security

1. **Non-Root User**: The Dockerfile creates and uses a non-root user (`appuser`)
2. **Minimal Base Image**: Uses Alpine-based images for smaller attack surface
3. **No Secrets in Image**: Never bake secrets into the Docker image

### Network Security

1. **Security Groups**: Restrict inbound traffic to necessary ports only
2. **Private Subnets**: Consider using private subnets with NAT Gateway for production
3. **VPC Endpoints**: Use VPC endpoints for ECR and CloudWatch to avoid internet traffic

### IAM Security

1. **Least Privilege**: Grant only necessary permissions to IAM roles
2. **Task Role**: Use separate task role for application-specific permissions
3. **Execution Role**: Limit execution role to ECR and CloudWatch access

### Secrets Management

Use AWS Secrets Manager or Systems Manager Parameter Store for sensitive data:

```json
"secrets": [
  {
    "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:region:account-id:secret:secret-name"
  }
]
```

### Image Scanning

Enable ECR image scanning:

```bash
aws ecr put-image-scanning-configuration \
  --repository-name modresorts \
  --image-scanning-configuration scanOnPush=true
```

---

## Scaling and Performance

### Service Auto Scaling

Configure auto scaling based on CPU or memory utilization:

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/modresorts-cluster/modresorts-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/modresorts-cluster/modresorts-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

**scaling-policy.json**:
```json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
  },
  "ScaleInCooldown": 300,
  "ScaleOutCooldown": 60
}
```

### Performance Tuning

1. **JVM Tuning**:
   - Adjust heap size based on workload
   - Use G1GC for better pause times: `-XX:+UseG1GC`
   - Enable GC logging: `-Xlog:gc*:file=/tmp/gc.log`

2. **Tomcat Tuning**:
   - Adjust thread pool size in `server.xml`
   - Configure connection timeout
   - Enable compression for responses

3. **Task Sizing**:
   - Monitor CPU and memory utilization
   - Right-size tasks based on actual usage
   - Consider using larger tasks for better performance

### Blue/Green Deployments

Use ECS deployment circuit breaker for safer deployments:

```json
"deploymentConfiguration": {
  "deploymentCircuitBreaker": {
    "enable": true,
    "rollback": true
  }
}
```

### Load Testing

Use tools like Apache JMeter or Gatling to test application performance:

```bash
# Example with Apache Bench
ab -n 10000 -c 100 http://alb-dns-name/health
```

---

## Additional Resources

### AWS Documentation
- [ECS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [ECS Task Definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html)
- [ECS Service Auto Scaling](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)

### Docker Documentation
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Multi-stage Builds](https://docs.docker.com/develop/develop-images/multistage-build/)

### Java/Tomcat Documentation
- [Tomcat Configuration](https://tomcat.apache.org/tomcat-9.0-doc/config/)
- [JVM Tuning Guide](https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/)

---

## Support and Maintenance

### Updating the Application

1. Make code changes
2. Build and push new image with new tag
3. Update task definition with new image
4. Update service to use new task definition

```bash
# Build and push new version
./scripts/build-push.sh

# Update service
aws ecs update-service \
  --cluster modresorts-cluster \
  --service modresorts-service \
  --task-definition modresorts-task:2 \
  --force-new-deployment
```

### Rollback

```bash
# Rollback to previous task definition
aws ecs update-service \
  --cluster modresorts-cluster \
  --service modresorts-service \
  --task-definition modresorts-task:1
```

### Cleanup

To remove all resources:

```bash
# Delete service
aws ecs delete-service \
  --cluster modresorts-cluster \
  --service modresorts-service \
  --force

# Delete cluster
aws ecs delete-cluster --cluster modresorts-cluster

# Delete ECR repository
aws ecr delete-repository \
  --repository-name modresorts \
  --force

# Delete CloudWatch log group
aws logs delete-log-group --log-group-name /ecs/modresorts

# Delete ALB and Target Group (if created)
aws elbv2 delete-load-balancer --load-balancer-arn arn:...
aws elbv2 delete-target-group --target-group-arn arn:...
```

---

## Conclusion

This guide provides comprehensive instructions for containerizing and deploying the ModResorts application to AWS ECS Fargate. Follow the steps carefully, and refer to the troubleshooting section for common issues.

For questions or issues, consult the AWS documentation or contact your DevOps team.

**Happy Deploying! 🚀**
