provider "aws" {
  region = var.region
}

# Create a VPC with subnets and Internet Gateway
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = {
    Name = "${var.project_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# Security Groups for Kubernetes Cluster
resource "aws_security_group" "k8s_master" {
  name        = "${var.project_name}-k8s-master-sg"
  description = "Security group for Kubernetes master nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "etcd server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "kube-scheduler"
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "kube-controller-manager"
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-k8s-master-sg"
  }
}

resource "aws_security_group" "k8s_worker" {
  name        = "${var.project_name}-k8s-worker-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    security_groups = [aws_security_group.k8s_master.id]
  }

  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all traffic from master nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.k8s_master.id]
  }

  ingress {
    description = "Allow all traffic from worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-k8s-worker-sg"
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "k8s_role" {
  name = "${var.project_name}-k8s-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "k8s_policy_attachment" {
  role       = aws_iam_role.k8s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR-FullAccess"
}

resource "aws_iam_role_policy_attachment" "k8s_ssm_policy_attachment" {
  role       = aws_iam_role.k8s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k8s_profile" {
  name = "${var.project_name}-k8s-profile"
  role = aws_iam_role.k8s_role.name
}

# EC2 Key Pair
resource "aws_key_pair" "k8s_key" {
  key_name   = "${var.project_name}-k8s-key"
  public_key = var.ssh_public_key
}

# EC2 Instances for Kubernetes Master
resource "aws_instance" "k8s_master" {
  ami                    = var.ami_id
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  vpc_security_group_ids = [aws_security_group.k8s_master.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.k8s_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              apt-get update
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io

              # Install kubeadm, kubelet, kubectl
              curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
              echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
              apt-get update
              apt-get install -y kubelet kubeadm kubectl
              apt-mark hold kubelet kubeadm kubectl

              # Initialize Kubernetes master
              kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

              # Set up kubeconfig for the ubuntu user
              mkdir -p /home/ubuntu/.kube
              cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube

              # Install Flannel network plugin
              su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

              # Generate join command for worker nodes
              kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
              chmod +x /home/ubuntu/join-command.sh
              EOF

  tags = {
    Name = "${var.project_name}-k8s-master"
  }
}

# EC2 Instances for Kubernetes Workers
resource "aws_instance" "k8s_worker" {
  count                  = var.worker_count
  ami                    = var.ami_id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  vpc_security_group_ids = [aws_security_group.k8s_worker.id]
  subnet_id              = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  iam_instance_profile   = aws_iam_instance_profile.k8s_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              apt-get update
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io

              # Install kubeadm, kubelet, kubectl
              curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
              echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
              apt-get update
              apt-get install -y kubelet kubeadm kubectl
              apt-mark hold kubelet kubeadm kubectl
              EOF

  tags = {
    Name = "${var.project_name}-k8s-worker-${count.index}"
  }

  depends_on = [aws_instance.k8s_master]
}

# Null resource to join worker nodes to the cluster
resource "null_resource" "join_workers" {
  count = var.worker_count

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = aws_instance.k8s_worker[count.index].public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 5; done",
      "sudo $(ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ubuntu@${aws_instance.k8s_master.public_ip} 'cat /home/ubuntu/join-command.sh')"
    ]
  }

  depends_on = [aws_instance.k8s_master, aws_instance.k8s_worker]
}

# Install Nginx Ingress Controller
resource "null_resource" "install_ingress" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = aws_instance.k8s_master.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml",
      "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s"
    ]
  }

  depends_on = [aws_instance.k8s_master]
}

# Create ECR repositories for our services
resource "aws_ecr_repository" "frontend" {
  name = "frontend"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "user_service" {
  name = "user-service"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "item_service" {
  name = "item-service"
  image_tag_mutability = "MUTABLE"
}

# Deploy Kubernetes manifests
resource "null_resource" "deploy_k8s_manifests" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = aws_instance.k8s_master.public_ip
  }

  provisioner "file" {
    source      = "../kubernetes"
    destination = "/home/ubuntu/kubernetes"
  }

  provisioner "remote-exec" {
    inline = [
      # Update image references in manifests
      "sed -i 's|image: frontend:latest|image: ${aws_ecr_repository.frontend.repository_url}:latest|g' /home/ubuntu/kubernetes/frontend-deployment.yaml",
      "sed -i 's|image: user-service:latest|image: ${aws_ecr_repository.user_service.repository_url}:latest|g' /home/ubuntu/kubernetes/user-service-deployment.yaml",
      "sed -i 's|image: item-service:latest|image: ${aws_ecr_repository.item_service.repository_url}:latest|g' /home/ubuntu/kubernetes/item-service-deployment.yaml",

      # Apply manifests
      "kubectl apply -f /home/ubuntu/kubernetes/frontend-deployment.yaml",
      "kubectl apply -f /home/ubuntu/kubernetes/user-service-deployment.yaml",
      "kubectl apply -f /home/ubuntu/kubernetes/item-service-deployment.yaml",
      "kubectl apply -f /home/ubuntu/kubernetes/ingress.yaml"
    ]
  }

  depends_on = [null_resource.install_ingress]
}
