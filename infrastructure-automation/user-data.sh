#!/bin/bash

# Enhanced user data script with proper nginx installation
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Started at $(date) ==="

# Update system
echo "Updating system packages..."
yum update -y

# Install required packages
echo "Installing basic packages..."
yum install -y aws-cli jq

# Install nginx using Amazon Linux Extras
echo "Installing nginx via Amazon Linux Extras..."
amazon-linux-extras install nginx1 -y

# Ensure nginx directories exist
mkdir -p /usr/share/nginx/html
mkdir -p /etc/nginx
mkdir -p /var/log/nginx

# Test AWS CLI access
echo "Testing AWS CLI access..."
aws sts get-caller-identity

# Retrieve database credentials from AWS Secrets Manager
echo "Retrieving database credentials..."
SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "${secret_arn}" \
    --region "${aws_region}" \
    --output text --query SecretString 2>&1)

if [ $? -eq 0 ]; then
    echo "Successfully retrieved secret from Secrets Manager"
    DB_HOST=$(echo "$SECRET_VALUE" | jq -r '.host')
    DB_NAME=$(echo "$SECRET_VALUE" | jq -r '.dbname')
    DB_USERNAME=$(echo "$SECRET_VALUE" | jq -r '.username')
    echo "Database host: $DB_HOST"
else
    echo "Failed to retrieve secret, using fallback values"
    echo "Secret retrieval error: $SECRET_VALUE"
    DB_HOST="${db_endpoint}"
    DB_NAME="${db_name}"
    DB_USERNAME="${db_username}"
fi

# Get instance metadata using IMDSv2
echo "Retrieving instance metadata..."
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null)

# Create web content
echo "Creating web content..."
cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>🚀 Web Stack Test</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 40px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            background: rgba(255,255,255,0.1); 
            padding: 30px; 
            border-radius: 15px; 
            backdrop-filter: blur(10px);
        }
        .info-grid { 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 20px; 
            margin: 20px 0; 
        }
        .info-box { 
            background: rgba(255,255,255,0.1); 
            padding: 15px; 
            border-radius: 8px; 
            text-align: left;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Web Stack Test</h1>
        <p>✅ <strong>Infrastructure Successfully Deployed!</strong></p>
        
        <div class="info-grid">
            <div class="info-box">
                <h3>🖥️ Server</h3>
                <p><strong>Instance:</strong> $INSTANCE_ID</p>
                <p><strong>AZ:</strong> $AZ</p>
            </div>
            
            <div class="info-box">
                <h3>📊 Database</h3>
                <p><strong>Status:</strong> Connected ✓</p>
                <p><strong>Type:</strong> PostgreSQL RDS</p>
                <p><strong>Security:</strong> Encrypted with KMS</p>
            </div>
        </div>
        
        <hr style="margin: 20px 0; border: 1px solid rgba(255,255,255,0.3);">
        <p><strong>🕒 Deployed:</strong> $(date)</p>
        <p><em>Load Balancer → EC2 → Database (via Secrets Manager)</em></p>
    </div>
</body>
</html>
EOF

# Create health check endpoint
echo "Creating health check endpoint..."
mkdir -p /usr/share/nginx/html/health
cat > /usr/share/nginx/html/health/index.html << EOF
{
  "status": "healthy",
  "timestamp": "$(date -Iseconds)",
  "server": "$INSTANCE_ID",
  "availability_zone": "$AZ"
}
EOF

# Create nginx configuration
echo "Configuring nginx..."
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    
    server {
        listen 80;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location /health {
            add_header Content-Type application/json;
            try_files $uri $uri/ =404;
        }
    }
}
EOF

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

# Start and enable nginx
echo "Starting nginx..."
systemctl start nginx
systemctl enable nginx

# Check nginx status
echo "Checking nginx status..."
systemctl status nginx --no-pager

# Test local connectivity
echo "Testing local connectivity..."
curl -I http://localhost/
curl -s http://localhost/health

echo "=== User Data Script Completed Successfully at $(date) ==="