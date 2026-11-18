variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "vpc_name" {
  type        = string
  description = "Tag Name da VPC criada pelo fiap-garageflow-k8s-infra"
  default     = "garage-flow-vpc"
}

variable "db_instance_identifier" {
  type        = string
  description = "Identificador da instância RDS criada pelo fiap-garageflow-db-infra"
  default     = "garage-flow"
}

variable "db_name" {
  type        = string
  description = "Banco com a tabela Customers (criada pelas migrations do fiap-garageflow-api)"
  default     = "garage-flow"
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "jwt_issuer" {
  type    = string
  default = "GarageFlowService"
}

variable "jwt_audience" {
  type    = string
  default = "GarageFlowServiceClients"
}
