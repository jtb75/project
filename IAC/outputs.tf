output "cluster_name" {
  description = "Kubernetes Cluster Config"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${local.cluster_name}"
}

output "mongo_server" {
  description = "Mongo Public Connection"
  value       = "ssh -i ${var.key_pair}.pem ubuntu@${module.ec2_instance.0.public_dns}"
}

output "frontend_lb" {
  description = "Frontend Load Balncer"
  value       = kubernetes_service.frontend.status.0.load_balancer.0.ingress.0.hostname
}
