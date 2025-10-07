output "alb_dns_name" {
  value       = aws_lb.predictor_alb.dns_name
  description = "URL pública direta do ALB (sem API Key)"
}

output "api_invoke_base" {
  value       = "https://${aws_api_gateway_rest_api.ecs_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.ecs_stage.stage_name}"
  description = "Base URL do API Gateway"
}

output "api_predict_url" {
  value       = "https://${aws_api_gateway_rest_api.ecs_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.ecs_stage.stage_name}/predict"
  description = "Endpoint /predict (exige x-api-key)"
}

output "api_docs_url" {
  value       = "https://${aws_api_gateway_rest_api.ecs_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.ecs_stage.stage_name}/docs"
  description = "Swagger UI público"
}

output "api_openapi_url" {
  value       = "https://${aws_api_gateway_rest_api.ecs_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.ecs_stage.stage_name}/openapi.json"
  description = "OpenAPI JSON público"
}

output "api_key_value" {
  value       = aws_api_gateway_api_key.ecs_key.value
  sensitive   = true
  description = "Use no header x-api-key no /predict"
}
