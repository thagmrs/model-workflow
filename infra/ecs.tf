# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-ecs-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "predictor_task" {
  family                   = "${var.project_name}-predictor-task"
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  cpu                       = "512"
  memory                    = "1024"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "predictor"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-2.amazonaws.com/${var.ecr_inference_repo}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "ARTIFACTS_BUCKET", value = var.s3_artifacts_bucket },
        { name = "MODEL_KEY", value = "models/latest/model.joblib" },
        { name = "API_KEY", value = var.api_key }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.project_name}-predictor"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-predictor"
  retention_in_days = 7
}

# ECS Service
resource "aws_ecs_service" "predictor_service" {
  name            = "${var.project_name}-predictor-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.predictor_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_service_sg.id]
  }


  load_balancer {
    target_group_arn = aws_lb_target_group.predictor_tg.arn
    container_name   = "predictor"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.predictor_tg
  ]
}
