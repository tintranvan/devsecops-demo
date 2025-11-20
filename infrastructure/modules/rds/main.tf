# RDS Aurora Serverless Module with IAM Authentication

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# DB Security Group
resource "aws_security_group" "rds" {
  name_prefix = "${var.name_prefix}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.name_prefix}-aurora-cluster"

  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "15.8"
  database_name      = "devsecops"
  master_username    = "postgres"
  manage_master_user_password = true

  # IAM Database Authentication
  iam_database_authentication_enabled = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  # Backup configuration
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Security
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn

  # Deletion protection
  skip_final_snapshot = true
  deletion_protection = false

  # Performance Insights
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.common_tags
}

# Aurora Serverless v2 Instance
resource "aws_rds_cluster_instance" "main" {
  identifier         = "${var.name_prefix}-aurora-instance"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn

  tags = var.common_tags
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7

  tags = var.common_tags
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# RDS Monitoring Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# IAM Database User for Application
resource "aws_iam_role" "db_user_role" {
  name = "${var.name_prefix}-db-user-role"

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

# IAM Policy for RDS Connect
resource "aws_iam_role_policy" "db_connect" {
  name = "${var.name_prefix}-db-connect-policy"
  role = aws_iam_role.db_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.main.cluster_identifier}/app_user"
        ]
      }
    ]
  })
}

# Database user creation - requires psql client (commented out for now)
# resource "null_resource" "create_db_user" {
#   depends_on = [aws_rds_cluster_instance.main]
# 
#   provisioner "local-exec" {
#     command = <<-EOT
#       # Wait for cluster to be available
#       aws rds wait db-cluster-available --db-cluster-identifier ${aws_rds_cluster.main.cluster_identifier}
#       
#       # Create IAM database user
#       PGPASSWORD=$(aws rds generate-db-auth-token \
#         --hostname ${aws_rds_cluster.main.endpoint} \
#         --port 5432 \
#         --username postgres \
#         --region ${data.aws_region.current.name}) \
#       psql -h ${aws_rds_cluster.main.endpoint} \
#            -p 5432 \
#            -U postgres \
#            -d devsecops \
#            -c "CREATE USER app_user; GRANT rds_iam TO app_user; GRANT ALL PRIVILEGES ON DATABASE devsecops TO app_user;"
#     EOT
#   }
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
