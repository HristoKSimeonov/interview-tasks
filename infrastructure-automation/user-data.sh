#!/bin/bash

# Enhanced user data script with proper nginx installation for Amazon Linux 2
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Started at $(date) ==="

# Update system
echo "Updating system packages..."
yum update -y

# Install required packages
echo "Installing basic packages..."
yum install -y aws-cli jq

# Install nginx using Amazon Linux Extras (proper method)
echo "Installing nginx via Amazon Linux Extras..."
amazon-linux-extras install -y nginx1

# Alternative installation if amazon-linux-extras fails
if ! command -v nginx &> /dev/null; then
    echo "Amazon Linux Extras nginx installation failed, trying alternative method..."
    amazon-linux-extras enable nginx1
    yum clean metadata
    yum install -y nginx
fi

# Verify nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "ERROR: nginx installation failed completely"
    exit 1
fi

echo "nginx successfully installed"

# Ensure nginx directories exist and have correct permissions
echo "Setting up nginx directories..."
mkdir -p /usr/share/nginx/html
mkdir -p /etc/nginx/conf.d
mkdir -p /var/log/nginx
mkdir -p /var/lib/nginx
mkdir -p /var/cache/nginx

# Set correct ownership
chown -R nginx:nginx /usr/share/nginx/html
chown -R nginx:nginx /var/log/nginx
chown -R nginx:nginx /var/lib/nginx
chown -R nginx:nginx /var/cache/nginx

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

# Set correct ownership for web content
chown nginx:nginx /usr/share/nginx/html/index.html

# Create health check endpoint
echo "Creating health check endpoint..."
cat > /usr/share/nginx/html/health.json << EOF
{
  "status": "healthy",
  "timestamp": "$(date -Iseconds)",
  "server": "$INSTANCE_ID",
  "availability_zone": "$AZ"
}
EOF

chown nginx:nginx /usr/share/nginx/html/health.json

# Create nginx configuration (backup original first)
echo "Configuring nginx..."
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup 2>/dev/null || true

cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Include additional configuration files
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
            try_files $uri $uri/ =404;
        }

        location /health {
            add_header Content-Type application/json;
            try_files /health.json =404;
        }

        # Simple health check endpoint
        location /ping {
            add_header Content-Type text/plain;
            return 200 "pong\n";
        }

        error_page   404              /404.html;
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
EOF

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

if [ $? -ne 0 ]; then
    echo "ERROR: nginx configuration test failed"
    cat /etc/nginx/nginx.conf
    exit 1
fi

echo "nginx configuration test passed"

# Start and enable nginx
echo "Starting nginx..."
systemctl start nginx

if [ $? -eq 0 ]; then
    echo "nginx started successfully"
    systemctl enable nginx
else
    echo "ERROR: Failed to start nginx"
    systemctl status nginx --no-pager
    exit 1
fi

# Check nginx status
echo "Checking nginx status..."
systemctl status nginx --no-pager

# Test local connectivity
echo "Testing local connectivity..."
curl -I http://localhost/ || echo "Health check on / failed"
curl -s http://localhost/health || echo "Health check on /health failed"
curl -s http://localhost/ping || echo "Health check on /ping failed"

# Ensure SSM agent is running (it should be by default on Amazon Linux 2)
echo "Checking SSM agent status..."
systemctl status amazon-ssm-agent --no-pager
systemctl start amazon-ssm-agent 2>/dev/null || echo "SSM agent already running or failed to start"
systemctl enable amazon-ssm-agent

echo "=== User Data Script Completed Successfully at $(date) ==="