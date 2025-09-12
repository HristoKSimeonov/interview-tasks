#!/bin/bash

# Redirect all output to a log file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Started at $(date) ==="

# Update and install packages
yum update -y
yum install -y aws-cli nginx

# Create web content
mkdir -p /usr/share/nginx/html

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null)

# Create HTML page
cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Web Stack Test</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .box { border: 1px solid #ccc; padding: 20px; margin: 10px 0; }
    </style>
</head>
<body>
    <h1>Web Stack Test</h1>
    <p><strong>Infrastructure Successfully Deployed!</strong></p>
    
    <div class="box">
        <h3>Server Info</h3>
        <p>Instance: INSTANCE_ID_PLACEHOLDER</p>
        <p>Zone: AZ_PLACEHOLDER</p>
    </div>
    
    <div class="box">
        <h3>Database</h3>
        <p>Status: Connected</p>
        <p>Type: PostgreSQL RDS</p>
        <p>Security: Encrypted with KMS</p>
    </div>
    
    <p>Deployed: DEPLOY_TIME_PLACEHOLDER</p>
    <p>Architecture: Load Balancer -> EC2 -> Database (via Secrets Manager)</p>
</body>
</html>
EOF

# Replace placeholders with actual values
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /usr/share/nginx/html/index.html
sed -i "s/AZ_PLACEHOLDER/$AZ/g" /usr/share/nginx/html/index.html
sed -i "s/DEPLOY_TIME_PLACEHOLDER/$(date)/g" /usr/share/nginx/html/index.html

# Create health check endpoint
cat > /usr/share/nginx/html/health.json << EOF
{
  "status": "healthy",
  "timestamp": "$(date -Iseconds)",
  "server": "$INSTANCE_ID",
  "availability_zone": "$AZ"
}
EOF

# Nginx config
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
    
    server {
        listen 80;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location /health {
            add_header Content-Type application/json;
            try_files /health.json =404;
        }

        location /ping {
            add_header Content-Type text/plain;
            return 200 "pong\n";
        }
    }
}
EOF

# Set ownership and start nginx
chown -R nginx:nginx /usr/share/nginx/html
systemctl start nginx
systemctl enable nginx

echo "=== User Data Script Completed at $(date) ==="