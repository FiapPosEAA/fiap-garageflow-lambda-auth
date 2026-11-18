# Ponto de entrada HTTPS único para a UI: o API Gateway encaminha para os NLBs criados pelo EKS.
locals {
  app_namespace = "garage-flow-namespace"

  backends = {
    os        = "garageflow-os-service"
    billing   = "garageflow-billing-service"
    execution = "garageflow-execution-service"
  }

  backend_routes = {
    "POST /work-orders"         = "os"
    "GET /work-orders/{id}"     = "os"
    "POST /quotes"              = "billing"
    "GET /quotes/{id}"          = "billing"
    "POST /quotes/{id}/approve" = "billing"
    "POST /quotes/{id}/payment" = "billing"
    "POST /payments/webhook"    = "billing"
    "POST /executions"          = "execution"
    "GET /executions/{id}"      = "execution"
  }
}

data "aws_lb" "backend" {
  for_each = local.backends

  tags = {
    "service.eks.amazonaws.com/stack" = "${local.app_namespace}/${each.value}"
  }
}

resource "aws_apigatewayv2_integration" "backend" {
  for_each = local.backends

  api_id             = aws_apigatewayv2_api.auth.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "http://${data.aws_lb.backend[each.key].dns_name}"

  request_parameters = {
    "overwrite:path" = "$request.path"
  }
}

resource "aws_apigatewayv2_route" "backend" {
  for_each = local.backend_routes

  api_id    = aws_apigatewayv2_api.auth.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.backend[each.value].id}"
}
