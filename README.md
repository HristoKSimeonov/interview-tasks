# interview-tasks
Contains solutions for 2 technical tasks as part of my interview process.

## Task 1 - Certificate Expiry Date Checker Script

A Python script that checks and displays the expiration date of SSL/TLS certificates for a set of websites with configurable thresholds, Slack webhook notifications, and automated daily scheduling.

### Features

- Checks multiple websites concurrently for performance
- **Configurable thresholds for warning/error alerts**
- **Slack webhook notifications with rich formatting**
- **Automated daily execution via cronjob**
- Detailed logging and error handling
- Human-readable output with status indicators
- JSON output for automation
- Docker containerization
- Graceful error handling for network issues

### Prerequisites

- Python 3.11 or higher
- Docker (for containerized execution)
- Slack workspace with incoming webhook configured
- Cron service running (for automated scheduling)

### Configuration

#### Thresholds

Configure alert thresholds in `config.json`:

```json
"thresholds": {
    "critical": 7,
    "warning": 30
}
```

#### Slack Webhook

Configure Slack webhook in `config.json`:

```json
"slack_webhook": {
    "enabled": true,
    "url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
    "send_on_critical": true,
    "send_on_warning": false
}
```

### Usage

#### Local Usage

1. Create and activate virtual environment:
```bash
cd cert_checker
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure settings in `config.json`

4. Run the script:
```bash
python main.py
```

5. Run tests:
```bash
python test_checker.py
```

6. Deactivate virtual environment when done:
```bash
deactivate
```

#### Docker Usage

1. Build the Docker image:
```bash
cd cert_checker
docker build -t cert-checker .
```

2. Run the container:
```bash
docker run --rm cert-checker
```

#### Automated Scheduling with Cronjob

The script includes automated daily execution using Docker and cronjob.

**Setup Cronjob:**

1. **Make the script executable:**
```bash
cd cert_checker
chmod +x run_cert_checker_docker.sh
```

2. **Test the script manually:**
```bash
./run_cert_checker_docker.sh
```

3. **Set up daily cronjob (9 AM):**
```bash
crontab -e
# Add this line:
0 9 * * * /home/user/cert_checker/run_cert_checker_docker.sh
```

4. **Verify cronjob is scheduled:**
```bash
crontab -l
```

**Cronjob Features:**
- ✅ **Daily execution** at 9:00 AM
- ✅ **Docker containerized** for consistency
- ✅ **Automatic Docker image building** if needed
- ✅ **Comprehensive logging** of all operations
- ✅ **Error handling** and exit code tracking
- ✅ **File output** preservation (results and logs)

### Monitoring and Logs

#### Primary Log Files

**Cronjob Execution Log:**
```bash
# Real-time monitoring
tail -f /home/user/cert_checker/cron_cert_checker_docker.log

# View recent runs
tail -50 /home/user/cert_checker/cron_cert_checker_docker.log
```

**Application Log:**
```bash
# Certificate checker application logs
tail -f /home/user/cert_checker/cert_checker.log
```

**Results File:**
```bash
# Latest certificate check results
cat /home/user/cert_checker/cert_results.json | jq '.'
```

### Output

The script provides:

#### Console Output
- Enhanced table showing URL, hostname, status, expiry date, and days until expiry
- **Color-coded status indicators**: 🟢 OK, 🟡 Warning, 🔴 Critical, ❌ Expired, ❗ Errors
- Summary statistics with threshold information
- **Threshold configuration display**

#### Slack Notifications
- **Rich message formatting** with colors and emojis
- **Critical alerts**: Red attachments for certificates requiring immediate attention
- **Warning alerts**: Orange attachments for certificates requiring attention soon (if enabled)
- **Summary information**: Total checked, critical count, warning count, configured thresholds
- **Automatic formatting**: Markdown support for better readability

#### Files Generated
- `cert_results.json`: Enhanced JSON output with thresholds and alert levels
- `cert_checker.log`: Detailed execution logs
- `cron_cert_checker_docker.log`: Cronjob execution and Docker operation logs

### Testing

#### Integration Testing

**Test Slack Webhook:**
```bash
curl -X POST -H 'Content-Type: application/json' \
--data '{"text":"🧪 Test message from Certificate Monitor"}' \
https://hooks.slack.com/services/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
```

**Test Docker Script:**
```bash
cd cert_checker
./run_cert_checker_docker.sh
```

**Force Critical Alert Test:**
To test Slack alerts, temporarily modify thresholds in `test_config.json`:
```json
{
    "thresholds": {
        "critical": 365,
        "warning": 400
    }
}
```
This will make all certificates appear critical and trigger Slack notifications.

### Advanced Usage

#### Custom Thresholds
Adjust thresholds based on your organization's requirements:
```json
{
    "thresholds": {
        "critical": 14,
        "warning": 60
    }
}
```

#### Custom Scheduling
Modify the cronjob schedule as needed:
```bash
crontab -e

# Examples:
0 9 * * *         # Daily at 9:00 AM
0 9 * * 1-5       # Weekdays at 9:00 AM  
0 9,17 * * *      # Daily at 9:00 AM and 5:00 PM
0 9 */3 * *       # Every 3 days at 9:00 AM
```

### Alerts and Notifications

#### When You'll Get Slack Alerts

**Based on default configuration:**
- 🚨 **CRITICAL**: Certificates expiring in ≤7 days
- ❌ **EXPIRED**: Already expired certificates  
- ❗ **ERROR**: Failed to check certificates
- 🟡 **WARNING**: Only if `send_on_warning: true` (disabled by default)

#### Alert Scenarios
- **No alerts**: All certificates are healthy (>30 days)
- **Warning alerts**: Certificates expiring in 8-30 days (if enabled)
- **Critical alerts**: Certificates expiring in ≤7 days or already expired
- **Error alerts**: Network issues, DNS failures, SSL errors

---

## Task 2 - Infrastructure Automation Setup

A comprehensive AWS infrastructure automation solution using Terraform that deploys a scalable web application stack with automated CI/CD pipeline.

### Quick Start Guide

#### Prerequisites
```bash
# Install required tools
terraform --version  # >= 1.0
aws --version        # AWS CLI configured
```

#### Setup Instructions

1. **Clone the repository:**
```bash
git clone https://github.com/your-username/interview-tasks.git
cd interview-tasks/infrastructure-automation
```

2. **Configure AWS credentials:**
```bash
aws configure
# OR set environment variables:
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=eu-central-1
```

3. **Initialize and deploy infrastructure:**
```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply
```

4. **Access your application:**
```bash
# Get the application URL from outputs
terraform output application_url
# Visit: http://web-stack-dev-alb-xxxxxxxx.eu-central-1.elb.amazonaws.com
```

### Architecture Overview

```
Internet Gateway
       ↓
[Application Load Balancer] (Public Subnets)
       ↓
[EC2 Web Servers] (Private Subnets)
       ↓                    ↓
[RDS PostgreSQL]    [AWS Secrets Manager + KMS]
(Private Subnets)
       ↓
[CloudWatch Logs]
```

### Infrastructure Components

This infrastructure uses a **secure multi-tier architecture** deployed across 2 availability zones:

#### Network Layer ([`network.tf`](infrastructure-automation/network.tf))

- **VPC**: Custom VPC (10.0.0.0/16) with DNS support
- **Public Subnets**: 2 subnets (10.0.0.0/24, 10.0.1.0/24) for ALB
- **Private Subnets**: 2 subnets (10.0.10.0/24, 10.0.11.0/24) for EC2/RDS
- **Internet Gateway**: Public internet access
- **NAT Gateway**: Secure outbound internet for private resources
- **Security Groups**: Layered security with least-privilege access
  - **ALB Security Group**: HTTP/HTTPS (80/443) from internet (0.0.0.0/0)
  - **Web Security Group**: HTTP (80) from ALB only, SSH (22) from VPC
  - **Database Security Group**: PostgreSQL (5432) from web servers only

#### Compute Layer ([`compute.tf`](infrastructure-automation/compute.tf))

- **Launch Template**: Standardized EC2 configuration with user-data bootstrapping
- **EC2 Instances**: Fixed deployment (1 instance per AZ)
- **Instance Type**: t2.micro (Free Tier eligible)
- **AMI**: Latest Amazon Linux 2
- **IAM Instance Profile**: Secure access to AWS Secrets Manager
- **Target Group**: Health check monitoring and load balancer integration
- **CloudWatch Logs**: Centralized logging for applications and system logs

#### Load Balancer ([`loadbalancer.tf`](infrastructure-automation/loadbalancer.tf))

- **Application Load Balancer**: Internet-facing, multi-AZ deployment
- **Target Group**: Advanced health checks (30s interval, 2 healthy threshold)
- **HTTP Listener**: Port 80 traffic forwarding
- **Health Check Path**: `/` with 200 OK response expected
- **Automatic Failover**: Unhealthy instances automatically removed

#### Database Layer ([`database.tf`](infrastructure-automation/database.tf))

- **RDS PostgreSQL 15.8**: Managed database service
- **Instance Class**: db.t3.micro (Free Tier eligible)
- **Multi-AZ Subnet Group**: High availability deployment
- **Storage**: 20GB GP2 with encryption at rest
- **Automated Backups**: 7-day retention, daily backups
- **Maintenance Window**: Sunday 04:00-05:00 UTC
- **No Public Access**: Database isolated in private subnets

#### Security & Secrets Management ([`kms.tf`](infrastructure-automation/kms.tf))

- **KMS Customer Managed Key**: Database credential encryption
- **Key Rotation**: Automatic annual key rotation enabled
- **AWS Secrets Manager**: Encrypted database credentials storage
- **Random Password Generation**: 20-character secure passwords
- **IAM Roles & Policies**: Least-privilege access for EC2 instances
- **SSM Access**: EC2 instances can be managed via Systems Manager

### Deployed Web Application

The infrastructure automatically deploys a web application via the [`user-data.sh`](infrastructure-automation/user-data.sh) script:

#### Technology Stack
- **Web Server**: Nginx on Amazon Linux 2
- **Configuration**: Custom nginx.conf with access logging
- **Bootstrap Script**: Automated installation and configuration
- **Security Integration**: AWS Secrets Manager for database credentials
- **Monitoring**: CloudWatch Logs agent with structured logging

#### Application Features
- **Dynamic Content**: Displays real server information (Instance ID, AZ)
- **Database Integration**: Connection status with PostgreSQL RDS
- **Security Status**: KMS encryption and Secrets Manager integration
- **Health Endpoints**: Multiple monitoring endpoints
- **Access Logging**: Comprehensive Nginx access and error logs

#### Available Endpoints

```bash
# Main application page
curl http://$(terraform output -raw load_balancer_dns_name)/

# Health check (JSON response)
curl http://$(terraform output -raw load_balancer_dns_name)/health

# Simple ping endpoint
curl http://$(terraform output -raw load_balancer_dns_name)/ping
```

**Sample Health Check Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T10:30:45+00:00",
  "server": "i-0123456789abcdef0",
  "availability_zone": "eu-central-1a",
  "logs": {
    "cloudwatch_enabled": true,
    "log_group": "/aws/ec2/web-stack-dev"
  }
}
```

### CI/CD Pipeline

#### GitHub Actions Workflow ([`.github/workflows/terraform-infra.yml`](.github/workflows/terraform-infra.yml))

**Automated Triggers:**
- ✅ **Push to main branch**: Automatic deployment on infrastructure changes
- ✅ **Manual workflow dispatch**: On-demand deployments with flexible options
- ✅ **Path-based triggers**: Only runs when infrastructure files change

**Workflow Features:**
- **Terraform Validation**: Format checking and configuration validation
- **Plan Generation**: Shows infrastructure changes before applying
- **Secure AWS Integration**: Uses GitHub Secrets for AWS credentials
- **Flexible Actions**: Plan-only, Apply, or Destroy operations
- **Output Display**: Shows application URLs and endpoints after deployment
- **Error Handling**: Proper exit codes and failure notifications

**Usage:**

1. **Configure GitHub Repository Secrets:**
```
Settings → Secrets and variables → Actions → Repository secrets

AWS_ACCESS_KEY_ID     = AKIA...
AWS_SECRET_ACCESS_KEY = xxxxx...
```

2. **Automatic Deployment (Push to main):**
```bash
# Make infrastructure changes
vim infrastructure-automation/variables.tf

# Commit and push
git add infrastructure-automation/
git commit -m "Update infrastructure configuration"
git push origin main

# GitHub Actions automatically triggers deployment
```

3. **Manual Deployment:**
   - Go to **Actions** tab in GitHub repository
   - Select **"Infrastructure Deployment"** workflow
   - Click **"Run workflow"**
   - Choose deployment action:
     - **plan**: Preview changes only
     - **apply**: Deploy infrastructure changes
     - **destroy**: Destroy infrastructure

4. **Monitor Deployment:**
   - View real-time logs in GitHub Actions
   - Check job outputs for application URLs
   - Monitor AWS Console for resource creation

### Code Structure and Configuration

#### File Organization
```
infrastructure-automation/
├── main.tf              # Main configuration and providers
├── variables.tf         # Input variables and defaults
├── terraform.tfvars     # Environment-specific values
├── outputs.tf           # Output values and endpoints
├── network.tf           # VPC, subnets, security groups
├── compute.tf           # EC2, launch templates, CloudWatch
├── loadbalancer.tf      # ALB, target groups, listeners
├── database.tf          # RDS PostgreSQL configuration
├── kms.tf               # Security, secrets, IAM roles
├── user-data.sh         # EC2 bootstrap script
└── s3_backend.tf        # Remote state configuration (commented)
```

#### Remote State Management

The infrastructure uses **S3 backend** for remote state storage:
- **S3 Bucket**: `dev-web-stack-tfstate-github-actions-bucket`
- **Region**: eu-central-1
- **Encryption**: AES256 server-side encryption
- **Versioning**: Enabled for state history
- **Access Control**: Private bucket with public access blocked

### Security Best Practices

#### Network Security
- **Zero Trust Network**: All resources in private subnets by default
- **Security Groups**: Stateful firewalls with specific port/protocol rules
- **Network ACLs**: Additional subnet-level security (using defaults)
- **NAT Gateway**: Single point of outbound internet access
- **No SSH Keys**: Instances accessible via AWS Systems Manager only

#### Data Protection
- **Encryption at Rest**: RDS storage encrypted with default AWS keys
- **Encryption in Transit**: TLS 1.2+ for all HTTPS communications
- **Secret Management**: Database credentials never stored in plain text
- **KMS Integration**: Customer-managed keys for sensitive data
- **Backup Encryption**: RDS backups automatically encrypted

#### Operational Security
- **Patch Management**: Amazon Linux 2 with automatic security updates
- **Monitoring**: CloudWatch metrics and logs for security events
- **Backup Strategy**: 7-day automated RDS backups
- **Disaster Recovery**: Multi-AZ deployment for high availability
- **Resource Cleanup**: Terraform destroy removes all resources cleanly

### Monitoring and Observability

#### Application Health Monitoring

**Load Balancer Health Checks:**
- **Path**: `/` (main application page)
- **Protocol**: HTTP
- **Port**: 80
- **Healthy Threshold**: 2 consecutive successful checks
- **Unhealthy Threshold**: 2 consecutive failed checks
- **Timeout**: 5 seconds
- **Interval**: 30 seconds