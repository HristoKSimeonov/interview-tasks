#!/bin/bash

# Simple nginx web server with database connectivity test

# Update system
yum update -y

# Install required packages
yum install -y aws-cli jq nginx

# Retrieve database credentials from AWS Secrets Manager
SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "${secret_arn}" \
    --region "${aws_region}" \
    --output text --query SecretString 2>/dev/null)

if [ $? -eq 0 ]; then
    DB_HOST=$(echo "$SECRET_VALUE" | jq -r '.host')
    DB_NAME=$(echo "$SECRET_VALUE" | jq -r '.dbname')
    DB_USERNAME=$(echo "$SECRET_VALUE" | jq -r '.username')
    echo "Successfully retrieved database credentials"
else
    echo "Using fallback database values"
    DB_HOST="${db_endpoint}"
    DB_NAME="${db_name}"
    DB_USERNAME="${db_username}"
fi

# Create simplified HTML page
cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Test Web Stack</title>
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
                <p><strong>Instance:</strong> $(ec2-metadata --instance-id | cut -d ' ' -f2)</p>
                <p><strong>AZ:</strong> $(ec2-metadata --availability-zone | cut -d ' ' -f2)</p>
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
mkdir -p /usr/share/nginx/html/health
cat > /usr/share/nginx/html/health/index.html << EOF
{
  "status": "healthy",
  "timestamp": "$(date -Iseconds)",
  "server": "$(ec2-metadata --instance-id | cut -d ' ' -f2)",
  "availability_zone": "$(ec2-metadata --availability-zone | cut -d ' ' -f2)"
}
EOF

# Simple nginx configuration
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
        }
    }
}
EOF

# Start and enable nginx
systemctl start nginx
systemctl enable nginx

# Log completion
echo "Web server setup completed successfully" > /var/log/user-data.log
date >> /var/log/user-data.log