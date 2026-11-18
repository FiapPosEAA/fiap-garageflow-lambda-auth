terraform {
  required_version = ">= 1.8.0"

  backend "s3" {}

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = path.module
  output_path = "${path.module}/lambda-auth.zip"
  # node_modules is kept: jsonwebtoken and mssql are runtime dependencies.
  excludes = [
    ".git",
    ".github",
    ".gitignore",
    ".terraform",
    ".terraform.lock.hcl",
    "*.tfstate",
    "*.tfstate.*",
    "*.tf",
    "Dockerfile",
    "README.md",
    "lambda-auth.zip",
  ]
}

resource "aws_iam_role" "lambda" {
  name = "garage-flow-lambda-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_vpc" "garage_flow" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.garage_flow.id]
  }

  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

data "aws_db_instance" "sql_server" {
  db_instance_identifier = var.db_instance_identifier
}

resource "aws_security_group" "lambda" {
  name        = "garage-flow-lambda-auth-sg"
  description = "Egress da Lambda de autenticacao"
  vpc_id      = data.aws_vpc.garage_flow.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lambda_function" "auth" {
  function_name    = "garage-flow-auth"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15
  memory_size      = 256

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST                     = data.aws_db_instance.sql_server.address
      DB_PORT                     = tostring(data.aws_db_instance.sql_server.port)
      DB_NAME                     = var.db_name
      DB_USER                     = var.db_user
      DB_PASSWORD                 = var.db_password
      DB_ENCRYPT                  = "true"
      DB_TRUST_SERVER_CERTIFICATE = "true"
      JWT_SECRET                  = var.jwt_secret
      JWT_ISSUER                  = var.jwt_issuer
      JWT_AUDIENCE                = var.jwt_audience
    }
  }
}

resource "aws_apigatewayv2_api" "auth" {
  name          = "garage-flow-auth-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "auth" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.auth.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.auth.api_endpoint
}

output "lambda_function_name" {
  value = aws_lambda_function.auth.function_name
}