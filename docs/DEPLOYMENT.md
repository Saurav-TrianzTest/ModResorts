# ContainerSanity - Deployment Guide (AWS EKS)

ContainerSanity (the ModResorts sample web application) is a Java 8, Maven-built web application. It was a WAR for IBM WebSphere; for the container it runs as an executable WAR on the embedded Tomcat of Spring Boot 2.6.5 (`java -jar app.war`), on port 8080 under the context path `/resorts`.

## 1. Prerequisites and system requirements

| Tool | Use |
|------|-----|
| Docker 20.10+ | build and push the image (and Docker Compose v2 for the local run) |
| AWS CLI v2 | ECR login, EKS kubeconfig |
| kubectl (within one minor version of the cluster) | deploy the manifests |
| eksctl | create the cluster (optional when a cluster exists) |
| JDK 8 and Maven 3.8 | only for a build outside Docker |

IAM permissions of the user or role that deploys: `ecr:GetAuthorizationToken`, `ecr:CreateRepository`, `ecr:DescribeRepositories`, `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage`, `eks:DescribeCluster`, plus an EKS access entry or `aws-auth` mapping that lets the user create resources in the cluster.

Sizing: each pod requests 250m CPU and 512Mi memory, and is limited to 500m CPU and 1Gi. The cluster needs the AWS Load Balancer Controller for the Ingress.

## 2. Local setup with Docker Compose

`docker-compose.yml` has one service, the application. There is no database or other infrastructure.

```bash
export WEATHER_API_KEY="<your Weather Underground key, or an empty string to use the built-in default data>"
docker compose up --build
```

`WEATHER_API_KEY` is mandatory for compose to start (`${WEATHER_API_KEY:?set WEATHER_API_KEY}`); it is a credential and is never written into a file. Optional: `JNDI_INITIAL_CONTEXT_FACTORY`, `JNDI_PROVIDER_URL`, `SPRING_PROFILES_ACTIVE`.

Open http://localhost:8080/resorts/ and the health check http://localhost:8080/resorts/health.
The `containersanity-logs` volume is mounted on `/app/logs`.

## 3. Build and push the image

Run from the repository root; the scripts never change directory.

* Linux/macOS: `./scripts/build-push.sh`
* Windows: `scripts\build-push.bat`

They ask for the registry (1. AWS ECR, 2. Docker Hub), then the details of the chosen one, then the image tag (empty means `latest`). For ECR they log in with `aws ecr get-login-password`, create the repository when it is missing, run `docker build -f Dockerfile -t <registry>/<repo>:<tag> .` and push. The full image URI is printed at the end: it is the input of the deploy script.

## 4. Deployment on AWS EKS

### 4.1 Create the cluster (once)

```bash
eksctl create cluster --name containersanity-cluster --region us-east-1 --nodes 2 --node-type t3.medium
```

Install the AWS Load Balancer Controller (IAM policy, service account, Helm chart `eks/aws-load-balancer-controller`) as described in the AWS documentation; the Ingress needs it.

### 4.2 Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name containersanity-cluster
kubectl cluster-info
```

### 4.3 Deploy

* Linux/macOS: `./scripts/deploy-image.sh`
* Windows: `scripts\deploy-image.bat`

The script asks for the AWS region, the cluster name, the image URI, the optional `JNDI_INITIAL_CONTEXT_FACTORY` and `JNDI_PROVIDER_URL` values, and the `WEATHER_API_KEY` credential (not echoed). It then: configures kubectl, fills the `{{...}}` placeholders of `kubernetes/deployment.yaml` (and restores the template afterwards), applies `namespace.yaml`, creates the Secret `containersanity-secrets` (`kubectl create secret generic ... --dry-run=client -o yaml | kubectl apply -f -`), applies `deployment.yaml`, `service.yaml` and `ingress.yaml`, waits with `kubectl rollout status deployment/containersanity -n containersanity`, shows `kubectl get pods,svc,ingress -n containersanity` and prints the application URL taken from the ingress.

### 4.4 The manifests

| File | Content |
|------|---------|
| `kubernetes/namespace.yaml` | Namespace `containersanity`, label `name: containersanity` |
| `kubernetes/deployment.yaml` | Deployment `containersanity`, 2 replicas, container port 8080, image `"{{IMAGE_URI}}"`, env `WEATHER_API_KEY` from Secret `containersanity-secrets` (key `weather-api-key`), `JNDI_*` placeholders, requests 250m/512Mi and limits 500m/1Gi, liveness and readiness probes on `/resorts/health` |
| `kubernetes/service.yaml` | Service `containersanity-service`, ClusterIP, port 80 to 8080 |
| `kubernetes/ingress.yaml` | Ingress `containersanity-ingress`, `kubernetes.io/ingress.class: alb`, `alb.ingress.kubernetes.io/scheme: internet-facing`, ALB health check path `/resorts/health`, host `containersanity.example.com` |

The ingress host `containersanity.example.com` is a placeholder: point your DNS at the ALB, or edit the host. The application lives under `/resorts/`.

## 5. Configuration management and environment variables

| Variable | Purpose | Where it comes from |
|----------|---------|---------------------|
| `PORT` | HTTP port (default 8080) | Deployment env |
| `SPRING_PROFILES_ACTIVE` | Spring profile (default `prod`; the project has no profile files) | Dockerfile / Deployment env |
| `WEATHER_API_KEY` | Weather Underground key; when empty, the application serves its default weather data | Secret `containersanity-secrets`, key `weather-api-key` |
| `JNDI_INITIAL_CONTEXT_FACTORY`, `JNDI_PROVIDER_URL` | optional JNDI settings of the weather servlet (they replace the values formerly fixed to WebSphere); empty means unused | Deployment env placeholders |
| `SERVER_DISPLAY_NAME`, `SERVER_FULL_NAME` | read by an unused helper of the weather servlet | not set |
| `JAVA_OPTS` | JVM options | Dockerfile |

## 6. Security considerations and best practices

* The credential lives only in the Kubernetes Secret, created at deploy time; it is not in the image, the manifests or compose.
* The container runs as the non-root user 1001. The runtime image has no package manager use and no extra tools.
* The application's WebSphere form-login/security settings (`web.xml` login-config) are not active in the embedded server, and its security constraints were already commented out in the project: put authentication in front of the service (for example an ALB with OIDC) before exposing it to real users.
* `log4j-core 2.14.1` is a dependency of the project (not used by the code); the image sets `-Dlog4j2.formatMsgNoLookups=true`. Upgrade it when you can.
* Use ECR image scanning, IRSA for AWS access, a TLS certificate on the ALB (`alb.ingress.kubernetes.io/certificate-arn`) and NetworkPolicies.
* Restrict who can read Secrets (RBAC) and enable envelope encryption of Secrets on the cluster.

## 7. Java notes

* **JVM settings**: `JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 ..."`. With the 1Gi limit, a 512m heap leaves room for metaspace, threads and Tomcat buffers. If you raise the memory limit, raise `-Xmx` (or drop it and let `MaxRAMPercentage` size the heap). On Java 8 the container flags need 8u191 or later; the base image `eclipse-temurin:8-jdk` satisfies this. Time zone `UTC`, charset UTF-8.
* **Start-up and shutdown**: the entrypoint is `sh -c "exec java $JAVA_OPTS -jar app.war"`, so the JVM is the first process and gets SIGTERM; `server.shutdown=graceful` lets requests finish.
* **Spring profiles**: `SPRING_PROFILES_ACTIVE` is `prod`; the project has no `application-<profile>` files, so it changes nothing yet.
* **Health endpoint**: the application had none. `HealthServlet` answers `GET /resorts/health` with `{"status":"UP"}` from start-up for as long as the process runs, on the application port 8080. Liveness and readiness probes and the ALB health check use it. (No Spring Boot Actuator: the application does not use Spring MVC.)
* **Packaging**: `mvn clean package -DskipTests` produces `target/modresorts-2.0.0.war`, an executable WAR (spring-boot-maven-plugin repackage, main class `com.acme.modres.Application`). JSP (`login.jsp`) is served by `tomcat-embed-jasper`.

## 8. Troubleshooting

**Pod failures**
* `kubectl get pods -n containersanity`, then `kubectl describe pod <pod> -n containersanity` and `kubectl logs <pod> -n containersanity`.
* `ImagePullBackOff`: wrong image URI, or the node role lacks ECR read access (`AmazonEC2ContainerRegistryReadOnly`).
* `CrashLoopBackOff` or `OOMKilled`: read the logs; raise the memory limit and `-Xmx` together.
* Probes failing: the probe path is `/resorts/health` (the context path is part of it); start-up takes about 10-30 s.
* `CreateContainerConfigError`: the Secret `containersanity-secrets` is missing; run the deploy script again or create it by hand.

**Service issues**
* `kubectl get endpoints containersanity-service -n containersanity` must list the pod IPs; the selector is `app: containersanity`.
* Test inside the cluster: `kubectl port-forward svc/containersanity-service 8080:80 -n containersanity`, then open http://localhost:8080/resorts/.

**Ingress problems**
* `kubectl describe ingress containersanity-ingress -n containersanity`; the ADDRESS stays empty when the AWS Load Balancer Controller is not installed (`kubectl logs -n kube-system deployment/aws-load-balancer-controller`).
* Targets unhealthy in the ALB: the health check path must be `/resorts/health` (set by the annotation).
* The DNS name `containersanity.example.com` must point to the ALB.

## 9. Scaling and management

* Scale: `kubectl scale deployment/containersanity --replicas=4 -n containersanity`.
* Autoscaling (HPA, needs metrics-server):
  `kubectl autoscale deployment containersanity --cpu-percent=70 --min=2 --max=10 -n containersanity`.
* Rolling update: push a new tag and run `kubectl set image deployment/containersanity containersanity=<new image URI> -n containersanity`, then `kubectl rollout status deployment/containersanity -n containersanity`.
* Rollback: `kubectl rollout history deployment/containersanity -n containersanity` and `kubectl rollout undo deployment/containersanity -n containersanity`.
* Nodes: `eksctl scale nodegroup --cluster containersanity-cluster --name <nodegroup> --nodes 3`.
* Clean up: `kubectl delete namespace containersanity`.

## 10. Notes on this build

The WebSphere-only APIs were removed from the code (logout, upper-casing, server name and naming settings). The container build was not run in the migration environment (no Docker there) and the application was not started; test the image locally with Docker Compose before the first deployment. The application has no tests.
