# Migration Guide: AWS ECS to Kubernetes on EC2

This guide provides a step-by-step approach to migrate your application from AWS ECS to Kubernetes running on EC2 instances.

## What We've Done So Far

We've created the necessary Kubernetes manifest files for your microservices application:

1. **Deployment and Service manifests** for each component:
   - `frontend-deployment.yaml` - For the React frontend
   - `user-service-deployment.yaml` - For the Node.js user service
   - `item-service-deployment.yaml` - For the Python item service

2. **Ingress manifest** to handle routing:
   - `ingress.yaml` - Routes traffic to the appropriate service based on URL paths

3. **Documentation**:
   - `README.md` - Detailed explanations of Kubernetes concepts and resources

## Migration Steps

### 1. Set Up a Container Registry

Before you can deploy to Kubernetes, you need a container registry to store your Docker images:

```bash
# Create ECR repositories (if using AWS ECR)
aws ecr create-repository --repository-name frontend
aws ecr create-repository --repository-name user-service
aws ecr create-repository --repository-name item-service

# Log in to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com
```

### 2. Build and Push Docker Images

Build your Docker images and push them to your container registry:

```bash
# Build images
docker build -t frontend:latest ./frontend
docker build -t user-service:latest ./user-service
docker build -t item-service:latest ./item-service

# Tag images for your registry
docker tag frontend:latest <your-registry>/frontend:latest
docker tag user-service:latest <your-registry>/user-service:latest
docker tag item-service:latest <your-registry>/item-service:latest

# Push images
docker push <your-registry>/frontend:latest
docker push <your-registry>/user-service:latest
docker push <your-registry>/item-service:latest
```

### 3. Update Image References in Kubernetes Manifests

Update the image references in your Kubernetes manifests to point to your container registry:

```bash
# Edit the manifests to update image references
sed -i 's|image: frontend:latest|image: <your-registry>/frontend:latest|g' kubernetes/frontend-deployment.yaml
sed -i 's|image: user-service:latest|image: <your-registry>/user-service:latest|g' kubernetes/user-service-deployment.yaml
sed -i 's|image: item-service:latest|image: <your-registry>/item-service:latest|g' kubernetes/item-service-deployment.yaml
```

### 4. Set Up a Kubernetes Cluster on EC2

Choose one of the following options to set up your Kubernetes cluster:

#### Option 1: Using kOps

```bash
# Install kOps
curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops
sudo mv kops /usr/local/bin/

# Create an S3 bucket for kOps state store
aws s3api create-bucket --bucket my-kops-state-store --region us-east-1

# Create the cluster
export KOPS_STATE_STORE=s3://my-kops-state-store
kops create cluster --name=kubernetes.mydomain.com --zones=us-east-1a --master-size=t3.medium --node-size=t3.medium --node-count=2

# Apply the configuration
kops update cluster --name kubernetes.mydomain.com --yes

# Validate the cluster
kops validate cluster --wait 10m
```

#### Option 2: Using eksctl for Amazon EKS

```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create an EKS cluster
eksctl create cluster \
  --name my-cluster \
  --version 1.24 \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

### 5. Install the Ingress Controller

Kubernetes doesn't come with an Ingress controller by default, so you need to install one:

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for the Ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 6. Deploy Your Application to Kubernetes

Apply your Kubernetes manifests:

```bash
# Apply the manifests
kubectl apply -f kubernetes/frontend-deployment.yaml
kubectl apply -f kubernetes/user-service-deployment.yaml
kubectl apply -f kubernetes/item-service-deployment.yaml
kubectl apply -f kubernetes/ingress.yaml

# Verify deployments
kubectl get deployments
kubectl get pods
kubectl get services
kubectl get ingress
```

### 7. Set Up DNS (Optional)

If you have a domain name, you can point it to your Ingress controller's external IP or load balancer:

```bash
# Get the external IP or hostname of your Ingress controller
kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Update your DNS records to point to this address
```

### 8. Set Up Monitoring and Logging

Install monitoring and logging tools:

```bash
# Install Prometheus and Grafana for monitoring
kubectl apply -f https://github.com/prometheus-operator/kube-prometheus/tree/main/manifests

# Install ELK Stack for logging (or use CloudWatch)
# This is more complex and requires multiple manifests
```

## Comparing AWS ECS and Kubernetes

### Similarities
- Both are container orchestration platforms
- Both support Docker containers
- Both provide scaling, load balancing, and service discovery

### Key Differences
1. **Control Plane**: ECS is AWS-specific, while Kubernetes is cloud-agnostic
2. **Complexity**: Kubernetes is more complex but more powerful and flexible
3. **Ecosystem**: Kubernetes has a larger ecosystem of tools and extensions
4. **Networking**: Different networking models (ECS uses VPC, Kubernetes uses its own networking)
5. **Service Discovery**: Kubernetes has built-in DNS-based service discovery

## Troubleshooting

### Common Issues

1. **Pod Pending Status**:
   ```bash
   kubectl describe pod <pod-name>
   ```
   Look for events that might indicate resource constraints or image pull issues.

2. **Service Not Accessible**:
   ```bash
   kubectl get endpoints <service-name>
   ```
   Ensure endpoints exist for your service.

3. **Ingress Not Working**:
   ```bash
   kubectl describe ingress microservices-ingress
   ```
   Check for errors in the Ingress configuration.

## Next Steps

1. **Implement CI/CD**: Set up a CI/CD pipeline to automate deployments to your Kubernetes cluster
2. **Configure Auto-scaling**: Set up Horizontal Pod Autoscaler to automatically scale your services
3. **Implement Health Checks**: Add readiness and liveness probes to your deployments
4. **Set Up Persistent Storage**: If your application needs persistent storage, configure PersistentVolumes