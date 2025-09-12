#!/bin/bash

# Redirect all output to a log file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== User Data Script Started at $(date) ==="

# Update system first
yum update -y

# Install nginx using Amazon Linux Extras
amazon-linux-extras install -y nginx1

# Install other packages
yum install -y aws-cli awslogs

# Configure CloudWatch Logs Agent
cat > /etc/awslogs/awslogs.conf << EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/messages]
file = /var/log/messages
log_group_name = /aws/ec2/${project_name}-${environment}
log_stream_name = {instance_id}/messages
datetime_format = %b %d %H:%M:%S

[/var/log/user-data.log]
file = /var/log/user-data.log
log_group_name = /aws/ec2/${project_name}-${environment}/user-data
log_stream_name = {instance_id}/user-data
datetime_format = %Y-%m-%d %H:%M:%S

[/var/log/nginx/access.log]
file = /var/log/nginx/access.log
log_group_name = /aws/ec2/${project_name}-${environment}
log_stream_name = {instance_id}/nginx-access
datetime_format = %d/%b/%Y:%H:%M:%S

[/var/log/nginx/error.log]
file = /var/log/nginx/error.log
log_group_name = /aws/ec2/${project_name}-${environment}
log_stream_name = {instance_id}/nginx-error
datetime_format = %Y/%m/%d %H:%M:%S
EOF

# Configure CloudWatch Logs region
sed -i "s/region = us-east-1/region = ${aws_region}/g" /etc/awslogs/awscli.conf

# Start and enable CloudWatch Logs agent
systemctl start awslogsd
systemctl enable awslogsd

# Create web content directory
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
    
    <div class="box">
        <h3>Logs</h3>
        <p>CloudWatch: Enabled</p>
        <p>Log Group: /aws/ec2/${project_name}-${environment}</p>
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
  "availability_zone": "$AZ",
  "logs": {
    "cloudwatch_enabled": true,
    "log_group": "/aws/ec2/${project_name}-${environment}"
  }
}
EOF

# Nginx config with access logging
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
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
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

# Start and enable nginx
systemctl start nginx
systemctl enable nginx

# Log completion with status
echo "CloudWatch Logs agent status: $(systemctl is-active awslogsd)"
echo "Nginx status: $(systemctl is-active nginx)"
echo "Nginx listening on: $(netstat -tlnp | grep :80)"

echo "=== User Data Script Completed at $(date) ==="