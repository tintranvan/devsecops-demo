# ECS Cluster Module - Basic cluster only

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_cluster.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.common_tags
}

# Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = var.fargate_base
    weight            = var.fargate_weight
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    base              = 0
    weight            = var.fargate_spot_weight
    capacity_provider = "FARGATE_SPOT"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_cluster" {
  name              = "/aws/ecs/cluster/${var.cluster_name}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}
