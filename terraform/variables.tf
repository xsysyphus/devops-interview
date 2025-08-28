variable "aws_region" {
  description = "Região da AWS para implantar os recursos."
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Nome do projeto, usado para nomear recursos."
  type        = string
  default     = "teste-api"
}

variable "vpc_cidr" {
  description = "Bloco CIDR para a VPC (ex: 10.0.0.0/16, 172.16.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  description = "Lista de blocos CIDR para as sub-redes públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  description = "Lista de blocos CIDR para as sub-redes privadas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "acm_certificate_arn" {
  description = "ARN do certificado SSL/TLS no ACM para o ALB."
  type        = string
  default     = "arn:aws:acm:us-east-2:693014165328:certificate/b458b57d-68d0-4d2e-a7d7-a58526e24b29"
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "app_desired_count" {
  description = "Número desejado de instâncias da aplicação"
  type        = number
  default     = 2
}

variable "nginx_desired_count" {
  description = "Número desejado de instâncias do Nginx"
  type        = number
  default     = 2
}
