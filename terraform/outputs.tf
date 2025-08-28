# --- Outputs importantes do projeto ---

output "ecr_repository_api_url" {
  description = "URL do repositório ECR para a API"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_nginx_url" {
  description = "URL do repositório ECR para o Nginx"
  value       = aws_ecr_repository.nginx.repository_url
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_api_name" {
  description = "Nome do serviço ECS da API"
  value       = aws_ecs_service.api.name
}

output "ecs_service_nginx_name" {
  description = "Nome do serviço ECS do Nginx"
  value       = aws_ecs_service.nginx.name
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "private_subnets" {
  description = "IDs das sub-redes privadas"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "IDs das sub-redes públicas"
  value       = aws_subnet.public[*].id
}

output "api_service_discovery_dns" {
  description = "DNS interno para o serviço da API"
  value       = "api.${var.project_name}.local"
}
