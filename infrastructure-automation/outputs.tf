# Output definitions for Terraform

# =============================================================================
# NETWORK OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (for ALB)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (for EC2 instances)"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# =============================================================================
# LOAD BALANCER OUTPUTS
# =============================================================================

output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "URL to access the web application"
  value       = "http://${aws_lb.main.dns_name}"
}

# =============================================================================
# COMPUTE OUTPUTS
# =============================================================================

output "web_instance_ids" {
  description = "IDs of the web server instances"
  value       = aws_instance.web[*].id
}

output "web_instance_private_ips" {
  description = "Private IP addresses of web servers"
  value       = aws_instance.web[*].private_ip
  sensitive   = true
}

# =============================================================================
# DATABASE OUTPUTS
# =============================================================================

output "database_endpoint" {
  description = "RDS PostgreSQL instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port (default: 5432)"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Name of the PostgreSQL database"
  value       = aws_db_instance.main.db_name
}

# =============================================================================
# SECURITY OUTPUTS
# =============================================================================

output "security_group_alb_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "security_group_web_id" {
  description = "ID of the web servers security group"
  value       = aws_security_group.web.id
}

output "security_group_database_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

# =============================================================================
# SECRETS MANAGEMENT OUTPUTS
# =============================================================================

output "db_secret_arn" {
  description = "ARN of the database credentials secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.arn
  sensitive   = true
}

output "kms_key_id" {
  description = "ID of the KMS key used for database secret encryption"
  value       = aws_kms_key.db_secret_key.key_id
  sensitive   = true
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for database secret encryption"
  value       = aws_kms_key.db_secret_key.arn
  sensitive   = true
}