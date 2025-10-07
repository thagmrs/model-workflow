# API GATEWAY
resource "aws_api_gateway_rest_api" "ecs_api" {
  name        = "${var.project_name}-ecs-api"
  description = "API Gateway proxy -> ALB -> ECS FastAPI"
}


# /predict (POST) 
resource "aws_api_gateway_resource" "predict_res" {
  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  parent_id   = aws_api_gateway_rest_api.ecs_api.root_resource_id
  path_part   = "predict"
}

resource "aws_api_gateway_method" "predict_post" {
  rest_api_id      = aws_api_gateway_rest_api.ecs_api.id
  resource_id      = aws_api_gateway_resource.predict_res.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "predict_integ" {
  rest_api_id             = aws_api_gateway_rest_api.ecs_api.id
  resource_id             = aws_api_gateway_resource.predict_res.id
  http_method             = aws_api_gateway_method.predict_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.predictor_alb.dns_name}/predict"
}


# /health (GET) 
resource "aws_api_gateway_resource" "health_res" {
  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  parent_id   = aws_api_gateway_rest_api.ecs_api.root_resource_id
  path_part   = "health"
}

resource "aws_api_gateway_method" "health_get" {
  rest_api_id      = aws_api_gateway_rest_api.ecs_api.id
  resource_id      = aws_api_gateway_resource.health_res.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "health_integ" {
  rest_api_id             = aws_api_gateway_rest_api.ecs_api.id
  resource_id             = aws_api_gateway_resource.health_res.id
  http_method             = aws_api_gateway_method.health_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.predictor_alb.dns_name}/health"
}


# /docs (GET) 
resource "aws_api_gateway_resource" "docs_res" {
  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  parent_id   = aws_api_gateway_rest_api.ecs_api.root_resource_id
  path_part   = "docs"
}

resource "aws_api_gateway_method" "docs_get" {
  rest_api_id      = aws_api_gateway_rest_api.ecs_api.id
  resource_id      = aws_api_gateway_resource.docs_res.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "docs_integ" {
  rest_api_id             = aws_api_gateway_rest_api.ecs_api.id
  resource_id             = aws_api_gateway_resource.docs_res.id
  http_method             = aws_api_gateway_method.docs_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.predictor_alb.dns_name}/docs"
}


# /openapi.json (GET) 
resource "aws_api_gateway_resource" "openapi_res" {
  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  parent_id   = aws_api_gateway_rest_api.ecs_api.root_resource_id
  path_part   = "openapi.json"
}

resource "aws_api_gateway_method" "openapi_get" {
  rest_api_id      = aws_api_gateway_rest_api.ecs_api.id
  resource_id      = aws_api_gateway_resource.openapi_res.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "openapi_integ" {
  rest_api_id             = aws_api_gateway_rest_api.ecs_api.id
  resource_id             = aws_api_gateway_resource.openapi_res.id
  http_method             = aws_api_gateway_method.openapi_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.predictor_alb.dns_name}/openapi.json"
}

# DEPLOYMENT + STAGE

resource "aws_api_gateway_deployment" "ecs_deploy" {
  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  depends_on = [
    aws_api_gateway_integration.predict_integ,
    aws_api_gateway_integration.health_integ,
    aws_api_gateway_integration.docs_integ,
    aws_api_gateway_integration.openapi_integ
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.predict_integ.id,
      aws_api_gateway_integration.health_integ.id,
      aws_api_gateway_integration.docs_integ.id,
      aws_api_gateway_integration.openapi_integ.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "ecs_stage" {
  deployment_id = aws_api_gateway_deployment.ecs_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.ecs_api.id
  stage_name    = "prod"
}


# API Key + Usage Plan ( /predict)
resource "aws_api_gateway_api_key" "ecs_key" {
  name    = "${var.project_name}-ecs-api-key"
  enabled = true
}

resource "aws_api_gateway_usage_plan" "ecs_plan" {
  name = "${var.project_name}-ecs-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.ecs_api.id
    stage  = aws_api_gateway_stage.ecs_stage.stage_name
  }

  throttle_settings {
    burst_limit = 50
    rate_limit  = 100
  }
}

resource "aws_api_gateway_usage_plan_key" "ecs_key_link" {
  key_id        = aws_api_gateway_api_key.ecs_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.ecs_plan.id
}
