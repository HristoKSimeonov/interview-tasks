# Simplified RDS configuration

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# Simplified RDS Instance (PostgreSQL)
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master_password.result

  # Storage configuration
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Disable enhanced monitoring to reduce costs
  monitoring_interval = 0

  # Other settings
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres"
  }
}