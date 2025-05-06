# Kubernetes Deployment Guide

This guide explains how to deploy the microservices application on Kubernetes running on EC2 instances. It provides detailed explanations of each Kubernetes resource and how they work together.

## Understanding Kubernetes Resources

### Deployments

**Purpose**: Deployments manage the creation and updating of Pods (containers) in Kubernetes.

**Why we need them**: 
- They ensure a specified number of replicas (copies) of your application are running
- They handle updates and rollbacks of your application
- They automatically restart Pods if they fail or are terminated

**Key components in our Deployments**:
- `replicas: 2` - Specifies that we want 2 copies of each service running for high availability
- `selector` - Tells the Deployment which Pods to manage (using labels)
- `template` - Defines the Pod configuration (containers, resources, etc.)
- `resources` - Specifies CPU and memory requests/limits for each container

### Services

**Purpose**: Services provide a stable network endpoint to connect to a set of Pods.

**Why we need them**:
- Pods are ephemeral (temporary) and can be created/destroyed at any time
- Services provide a stable IP address and DNS name to access your application
- They load balance traffic across all Pods that match their selector

**Types of Services**:
- `ClusterIP` (default) - Exposes the Service on an internal IP within the cluster
- `NodePort` - Exposes the Service on each Node's IP at a static port
- `LoadBalancer` - Exposes the Service externally using a cloud provider's load balancer
- `ExternalName` - Maps the Service to a DNS name

In our setup, we're using `ClusterIP` for all services because they'll be accessed through the Ingress.

### Ingress

**Purpose**: Ingress manages external access to services in a cluster, typically HTTP.

**Why we need it**:
- It provides a single entry point for all HTTP traffic to the cluster
- It routes traffic to different services based on rules (like URL paths)
- It can provide SSL termination, name-based virtual hosting, and more

**Key components in our Ingress**:
- `annotations` - Configure the Ingress controller behavior
- `rules` - Define how traffic is routed to services
- `paths` - Specify URL paths and which services they should route to

### Resource Requests and Limits

**Purpose**: Define how much CPU and memory a container needs and is allowed to use.

**Why they matter**:
- `requests` - The minimum resources that the container needs to run
- `limits` - The maximum resources that the container is allowed to use

Setting appropriate requests and limits helps:
- Ensure containers have enough resources to run properly
- Prevent a single container from consuming all resources on a node
- Allow Kubernetes to schedule Pods efficiently across nodes

## How These Components Work Together

1. **Deployments** create and manage Pods (containers)
2. **Services** provide stable network endpoints to access those Pods
3. **Ingress** routes external HTTP traffic to the appropriate Services
4. **Resource requests/limits** ensure proper resource allocation

When a user accesses your application:
1. Traffic first hits the Ingress
2. The Ingress routes the request to the appropriate Service based on the URL path
3. The Service load balances the request to one of the Pods managed by the Deployment
4. The Pod processes the request and returns a response

## Setting Up a Kubernetes Cluster on EC2

There are several ways to set up a Kubernetes cluster on EC2 instances:

### Option 1: Using kOps (Kubernetes Operations)

kOps is a tool that helps you create, destroy, upgrade, and maintain production-grade Kubernetes clusters.

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
```

### Option 2: Using eksctl to Create an Amazon EKS Cluster

Amazon EKS is a managed Kubernetes service that makes it easy to run Kubernetes on AWS without needing to install and operate your own Kubernetes control plane.

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

### Option 3: Manual Setup with kubeadm

For more control, you can set up Kubernetes manually using kubeadm:

1. Launch EC2 instances (one master, multiple workers)
2. Install Docker, kubelet, kubeadm, and kubectl on all nodes
3. Initialize the master node
4. Join worker nodes to the cluster

## Deploying Your Application

Once your cluster is set up:

```bash
# Apply the Kubernetes manifests
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

## Container Registry Setup

You'll need a container registry to store your Docker images. Options include:

1. **Amazon ECR**:
   ```bash
   # Create repositories
   aws ecr create-repository --repository-name frontend
   aws ecr create-repository --repository-name user-service
   aws ecr create-repository --repository-name item-service
   
   # Login to ECR
   aws ecr get-login-password | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com
   
   # Tag and push images
   docker tag frontend:latest <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest
   docker push <your-aws-account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest
   # Repeat for other services
   ```

2. **Docker Hub** or other public/private registries

## Monitoring and Logging

Set up monitoring and logging for your Kubernetes cluster:

1. **Prometheus and Grafana** for monitoring
2. **ELK Stack** or **CloudWatch** for logging

## Key Differences from ECS

1. **Orchestration**: Kubernetes has a more complex but more powerful orchestration model compared to ECS
2. **Networking**: Kubernetes uses a different networking model with services, ingress, and network policies
3. **Scaling**: Kubernetes has the Horizontal Pod Autoscaler for automatic scaling
4. **Storage**: Kubernetes uses PersistentVolumes and PersistentVolumeClaims for storage
5. **Service Discovery**: Kubernetes has built-in DNS-based service discovery