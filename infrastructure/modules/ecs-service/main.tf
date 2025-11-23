# ECS Service Module
# Creates ECS service with task definition, security group, and auto-scaling

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name_prefix}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn           = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = var.image_uri
      
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]
      
      secrets = var.secrets
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.common_tags

  # Keep old task definitions for rollback
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to prevent deregistration of old revisions
      revision
    ]
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.name_prefix}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Deployment Configuration (for fast deployment)
  deployment_minimum_healthy_percent = var.minimum_healthy_percent
  deployment_maximum_percent         = var.maximum_percent
  health_check_grace_period_seconds  = var.health_check_grace_period

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id, var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [aws_iam_role_policy.task_policy]

  tags = var.common_tags
}

# ALB Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.name_prefix}-${var.service_name}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = var.common_tags
}

# ALB Listener Rule
resource "aws_lb_listener_rule" "main" {
  listener_arn = var.alb_listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [var.domain_name]
    }
  }

  tags = var.common_tags
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.name_prefix}-${var.service_name}-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-${var.service_name}-sg"
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/ecs/service/${var.name_prefix}-${var.service_name}"
  retention_in_days = 30

  tags = var.common_tags
}

# IAM Roles
resource "aws_iam_role" "execution_role" {
  name = "${var.name_prefix}-${var.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "execution_role_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager access
resource "aws_iam_role_policy" "execution_secrets_policy" {
  count = length(var.secret_arns) > 0 ? 1 : 0
  name  = "${var.name_prefix}-${var.service_name}-execution-secrets-policy"
  role  = aws_iam_role.execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.secret_arns
      }
    ]
  })
}

resource "aws_iam_role" "task_role" {
  name = "${var.name_prefix}-${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "task_policy" {
  count = length(var.iam_permissions) > 0 ? 1 : 0
  name = "${var.name_prefix}-${var.service_name}-task-policy"
  role = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for permission in var.iam_permissions : {
        Effect = "Allow"
        Action = permission.actions
        Resource = permission.resources
      }
    ]
  })
}

# Auto Scaling (conditional)
resource "aws_appautoscaling_target" "ecs_target" {
  count = var.scaling_config.enabled ? 1 : 0

  max_capacity       = var.max_count
  min_capacity       = 1
  resource_id        = "service/${split("/", var.cluster_id)[1]}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_policy" {
  count = var.scaling_config.enabled && lookup(var.scaling_config, "cpu_target_value", null) != null ? 1 : 0

  name               = "${var.name_prefix}-${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.scaling_config.cpu_target_value
  }
}

resource "aws_appautoscaling_policy" "memory_policy" {
  count = var.scaling_config.enabled && lookup(var.scaling_config, "memory_target_value", null) != null ? 1 : 0

  name               = "${var.name_prefix}-${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.scaling_config.memory_target_value
  }
}
