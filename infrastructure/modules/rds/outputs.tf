output "db_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "db_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "db_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_rds_cluster.main.database_name
}

output "db_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "db_user_role_arn" {
  description = "ARN of the database user IAM role"
  value       = aws_iam_role.db_user_role.arn
}

output "cluster_identifier" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.main.cluster_identifier
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.main.arn
}

output "master_user_secret_arn" {
  description = "Aurora master user secret ARN"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}
