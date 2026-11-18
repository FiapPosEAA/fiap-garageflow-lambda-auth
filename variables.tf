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

variable "cors_allowed_origins" {
  type    = list(string)
  default = ["https://fiapposeaa.github.io", "http://localhost:5173"]
}

variable "datadog_api_key" {
  type        = string
  description = "API key do Datadog; vazio desativa a instrumentação (layers, handler e DD_*)"
  sensitive   = true
  default     = ""
}

variable "datadog_site" {
  type    = string
  default = "datadoghq.com"
}

variable "datadog_env" {
  type    = string
  default = "producao"
}

variable "datadog_node_layer_version" {
  type        = number
  description = "Versão do layer Datadog-Node20-x"
  default     = 144
}

variable "datadog_extension_layer_version" {
  type        = number
  description = "Versão do layer Datadog-Extension (x86_64)"
  default     = 103
}
