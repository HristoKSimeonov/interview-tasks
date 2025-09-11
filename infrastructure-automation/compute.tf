# EC2 instances configuration

# Launch Template for Web Servers (keep for consistency)
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-${var.environment}-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web.id]

  # Attach IAM instance profile for secret access
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_secret_access.name
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
    aws_region  = var.aws_region
    db_endpoint = aws_db_instance.main.endpoint
    db_name     = var.db_name
    db_username = var.db_username
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-web-server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 instances
resource "aws_instance" "web" {
  count = length(var.availability_zones)

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  subnet_id = aws_subnet.private[count.index].id

  tags = {
    Name = "${var.project_name}-${var.environment}-web-${count.index + 1}"
  }
}

# Target Group Attachments for Load Balancer
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}