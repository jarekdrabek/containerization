variable "region" {
  description = "AWS region to deploy resources"
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name of the project, used as prefix for resource names"
  default     = "containerization-app"
}

variable "container_port" {
  description = "Default container port for services"
  default     = 80
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  default     = "k8s-cluster"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
  # No default - must be provided
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file for connecting to EC2 instances"
  type        = string
  # No default - must be provided
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Ubuntu 20.04 LTS recommended)"
  default     = "ami-0caef02b518350c8b" # Ubuntu 20.04 LTS in eu-central-1
}

variable "master_instance_type" {
  description = "Instance type for Kubernetes master node"
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "Instance type for Kubernetes worker nodes"
  default     = "t3.medium"
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  default     = 2
}
