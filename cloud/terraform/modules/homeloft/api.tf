resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"

  dynamic "cors_configuration" {
    for_each = length(local.cors_origins) > 0 ? [1] : []
    content {
      allow_origins = local.cors_origins
      allow_methods = ["GET", "POST", "PUT", "OPTIONS"]
      allow_headers = ["authorization", "content-type"]
      max_age       = 3600
    }
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  name             = "${var.name_prefix}-cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = local.issuer
    audience = local.client_ids # matches `aud` (ID token) or `client_id` (access token)
  }

  lifecycle {
    precondition {
      condition     = local.create_pool || length(var.existing_user_pool_client_ids) > 0
      error_message = "existing_user_pool_client_ids is required when existing_user_pool_id is set."
    }
  }
}

resource "aws_apigatewayv2_integration" "api" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

locals {
  routes = {
    "GET /v1/health"                             = false
    "GET /v1/homes"                              = true
    "GET /v1/homes/{homeId}/entities"            = true
    "GET /v1/homes/{homeId}/entities/{entityId}" = true
    "POST /v1/homes/{homeId}/commands"           = true
    "GET /v1/homes/{homeId}/commands/{id}"       = true
    "GET /v1/homes/{homeId}/history/{entityId}"  = true
    "GET /v1/homes/{homeId}/prefs"               = true
    "PUT /v1/homes/{homeId}/prefs"               = true
  }
}

resource "aws_apigatewayv2_route" "this" {
  for_each           = local.routes
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = each.key
  target             = "integrations/${aws_apigatewayv2_integration.api.id}"
  authorization_type = each.value ? "JWT" : "NONE"
  authorizer_id      = each.value ? aws_apigatewayv2_authorizer.cognito.id : null
}

resource "aws_cloudwatch_log_group" "api_access" {
  count             = var.api_access_logs ? 1 : 0
  name              = "/aws/apigateway/${var.name_prefix}-api-access"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  dynamic "access_log_settings" {
    for_each = var.api_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_access[0].arn
      format = jsonencode({
        requestId = "$context.requestId", ip = "$context.identity.sourceIp", time = "$context.requestTimeEpoch",
        route     = "$context.routeKey", status = "$context.status", latencyMs = "$context.responseLatency",
        sub       = "$context.authorizer.claims.sub", authError = "$context.authorizer.error",
      })
    }
  }

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
