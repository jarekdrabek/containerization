output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "kubernetes_master_ip" {
  description = "Public IP address of the Kubernetes master node"
  value       = aws_instance.k8s_master.public_ip
}

output "kubernetes_worker_ips" {
  description = "Public IP addresses of the Kubernetes worker nodes"
  value       = aws_instance.k8s_worker[*].public_ip
}

output "ecr_frontend_repository_url" {
  description = "URL of the ECR repository for the frontend service"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_user_service_repository_url" {
  description = "URL of the ECR repository for the user service"
  value       = aws_ecr_repository.user_service.repository_url
}

output "ecr_item_service_repository_url" {
  description = "URL of the ECR repository for the item service"
  value       = aws_ecr_repository.item_service.repository_url
}

output "kubernetes_connection_command" {
  description = "Command to configure kubectl to connect to the Kubernetes cluster"
  value       = "scp -i ${var.ssh_private_key_path} ubuntu@${aws_instance.k8s_master.public_ip}:/home/ubuntu/.kube/config ~/.kube/config"
}

output "ingress_controller_endpoint" {
  description = "Endpoint for the Ingress controller (may take a few minutes to be available after deployment)"
  value       = "http://${aws_instance.k8s_master.public_ip}"
}
