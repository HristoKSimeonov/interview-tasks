# # S3 Backend Resources

# resource "aws_s3_bucket" "tfstate" {
#   bucket = "${var.environment}-web-stack-tfstate-github-actions-bucket"

#   tags = {
#     Name        = "${var.environment}-web-stack-tfstate-github-actions-bucket"
#     Environment = var.environment
#     Project     = var.project_name
#     Purpose     = "Terraform State Backend"
#   }
# }

# resource "aws_s3_bucket_versioning" "versioning_tfstate" {
#   bucket = aws_s3_bucket.tfstate.bucket
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "server_side_encryption" {
#   bucket = aws_s3_bucket.tfstate.bucket
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# # Block public access to the state bucket
# resource "aws_s3_bucket_public_access_block" "tfstate_pab" {
#   bucket = aws_s3_bucket.tfstate.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# # Output the bucket name for reference
# output "tfstate_bucket_name" {
#   description = "Name of the S3 bucket for Terraform state"
#   value       = aws_s3_bucket.tfstate.bucket
# }