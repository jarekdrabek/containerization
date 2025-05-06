# Terraform Configuration for Kubernetes on EC2

This Terraform configuration deploys a Kubernetes cluster on AWS EC2 instances for running the containerized microservices application.

## Architecture

The infrastructure consists of:

1. **VPC with public and private subnets** across two availability zones
2. **EC2 instances** for Kubernetes master and worker nodes
3. **Security groups** for controlling access to the instances
4. **IAM roles** for EC2 instances to access AWS services
5. **ECR repositories** for storing Docker images
6. **Kubernetes cluster** configured with kubeadm
7. **Nginx Ingress Controller** for routing external traffic

## Prerequisites

Before applying this Terraform configuration, you need:

1. **AWS CLI** installed and configured with appropriate credentials
2. **Terraform** installed (version 1.0.0 or later)
3. **SSH key pair** for accessing the EC2 instances
4. **Docker** installed for building and pushing images

## Required Variables

The following variables must be provided when applying the Terraform configuration:

- `ssh_public_key`: Your SSH public key for accessing EC2 instances
- `ssh_private_key_path`: Path to your SSH private key file

Example:

```bash
terraform apply \
  -var="ssh_public_key=ssh-rsa AAAA..." \
  -var="ssh_private_key_path=~/.ssh/id_rsa"
```

## Optional Variables

The following variables have default values but can be overridden:

- `region`: AWS region (default: "eu-central-1")
- `project_name`: Name prefix for resources (default: "containerization-app")
- `cluster_name`: Name of the Kubernetes cluster (default: "k8s-cluster")
- `ami_id`: AMI ID for EC2 instances (default: Ubuntu 20.04 LTS in eu-central-1)
- `master_instance_type`: Instance type for master node (default: "t3.medium")
- `worker_instance_type`: Instance type for worker nodes (default: "t3.medium")
- `worker_count`: Number of worker nodes (default: 2)

## Deployment Steps

1. **Initialize Terraform**:

   ```bash
   terraform init
   ```

2. **Plan the deployment**:

   ```bash
   terraform plan \
     -var="ssh_public_key=<your-ssh-public-key>" \
     -var="ssh_private_key_path=<path-to-your-private-key>"
   ```

3. **Apply the configuration**:

   ```bash
   terraform apply \
     -var="ssh_public_key=<your-ssh-public-key>" \
     -var="ssh_private_key_path=<path-to-your-private-key>"
   ```

4. **Configure kubectl** to connect to your cluster:

   ```bash
   # Use the command from the terraform output
   $(terraform output -raw kubernetes_connection_command)
   ```

5. **Build and push Docker images** to ECR:

   ```bash
   # Login to ECR
   aws ecr get-login-password | docker login --username AWS --password-stdin $(terraform output -raw ecr_frontend_repository_url | cut -d/ -f1)
   
   # Build and push frontend image
   docker build -t frontend:latest ./frontend
   docker tag frontend:latest $(terraform output -raw ecr_frontend_repository_url):latest
   docker push $(terraform output -raw ecr_frontend_repository_url):latest
   
   # Repeat for user-service and item-service
   ```

## Accessing the Application

Once deployed, you can access the application through the Ingress controller endpoint:

```bash
echo $(terraform output -raw ingress_controller_endpoint)
```

The application should be available at this URL after a few minutes.

## Cleanup

To destroy all resources created by Terraform:

```bash
terraform destroy \
  -var="ssh_public_key=<your-ssh-public-key>" \
  -var="ssh_private_key_path=<path-to-your-private-key>"
```

## Troubleshooting

1. **SSH to the master node**:

   ```bash
   ssh -i <your-private-key> ubuntu@$(terraform output -raw kubernetes_master_ip)
   ```

2. **Check Kubernetes cluster status**:

   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

3. **Check logs on the master node**:

   ```bash
   sudo journalctl -u kubelet
   ```

4. **If worker nodes fail to join**:

   ```bash
   # On master node
   kubeadm token create --print-join-command
   
   # Use this command on worker nodes
   ```