output "jira_url" {
  value       = "http://${aws_lb.jira_alb.dns_name}"
  description = "URL to access Jira"
}

output "db_endpoint" {
  value       = aws_db_instance.jira_db.endpoint
  sensitive   = true
  description = "RDS endpoint for database connection"
}

output "jira_instance_id" {
  value       = aws_instance.jira_server.id
  description = "EC2 instance ID for SSH session"
}
