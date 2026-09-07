variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "lambda_subnet_ids" {
  type        = list(string)
  description = "Subnets privadas com rota para o RDS"
}

variable "lambda_security_group_ids" {
  type        = list(string)
  description = "Security groups da Lambda"
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 1433
}

variable "db_name" {
  type = string
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