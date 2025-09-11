# KMS Key for encrypting secrets
resource "aws_kms_key" "db_secret_key" {
  description             = "KMS key for database secret encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-db-secret-key"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "db_secret_key_alias" {
  name          = "alias/${var.project_name}-${var.environment}-db-secret"
  target_key_id = aws_kms_key.db_secret_key.key_id
}

# Generate random password
resource "random_password" "db_master_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*+-=?^_`{|}~"
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-db-credentials"
  description             = "Database master credentials for RDS PostgreSQL"
  kms_key_id              = aws_kms_key.db_secret_key.arn
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-db-credentials"
  }
}

# Secrets Manager Secret Version
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  depends_on = [aws_db_instance.main]
  secret_id  = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })

}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_secret_access_role" {
  name = "${var.project_name}-${var.environment}-ec2-secret-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-secret-access-role"
  }
}

# IAM policy for EC2 instances to read the secret
resource "aws_iam_policy" "db_secret_access" {
  name        = "${var.project_name}-${var.environment}-db-secret-access"
  description = "Policy to allow reading database credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.db_secret_key.arn
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-db-secret-access-policy"
  }
}

# Attach the secret access policy to the role
resource "aws_iam_role_policy_attachment" "ec2_secret_access" {
  role       = aws_iam_role.ec2_secret_access_role.name
  policy_arn = aws_iam_policy.db_secret_access.arn
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_secret_access" {
  name = "${var.project_name}-${var.environment}-ec2-secret-access"
  role = aws_iam_role.ec2_secret_access_role.name

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-secret-access-profile"
  }
}