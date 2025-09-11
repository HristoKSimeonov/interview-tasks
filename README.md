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

A comprehensive AWS infrastructure automation solution using Terraform that deploys a web application stack.

### Architecture Overview

```
Internet
    ↓
[Application Load Balancer]
    ↓
[EC2 Instances (2 AZs)]
    ↓
[RDS PostgreSQL Database]
    ↓
[AWS Secrets Manager + KMS Encryption]
```

### Features

- **Multi-AZ High Availability**: Deployment across 2 availability zones
- **Application Load Balancer**: Internet-facing with health checks
- **Secure Database**: RDS PostgreSQL with encryption at rest
- **Secrets Management**: AWS Secrets Manager with KMS encryption
- **Network Security**: Private subnets, security groups, NAT Gateway
- **Infrastructure as Code**: 100% Terraform managed
- **CI/CD Ready**: GitHub Actions workflow

### Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** >= 1.0 installed
- **AWS CLI** configured with credentials
- **GitHub repository** (for CI/CD)

### Infrastructure Components

#### Network Layer ([`network.tf`](infrastructure-automation/network.tf))

- **VPC**: Custom VPC with DNS support
- **Subnets**: Public subnets for ALB, private subnets for EC2/RDS
- **Internet Gateway**: Internet access for public resources
- **NAT Gateway**: Outbound internet access for private resources
- **Security Groups**: Layer-4 firewall rules
  - ALB Security Group: HTTP/HTTPS from internet
  - Web Security Group: HTTP from ALB, SSH from VPC
  - Database Security Group: PostgreSQL from web servers only

#### Compute Layer ([`compute.tf`](infrastructure-automation/compute.tf))

- **Launch Template**: EC2 configuration template with user-data
- **EC2 Instances**: Fixed instances across availability zones
- **Target Group Attachments**: Connect instances to load balancer
- **IAM Instance Profile**: Permissions for Secrets Manager access

#### Load Balancer ([`loadbalancer.tf`](infrastructure-automation/loadbalancer.tf))

- **Application Load Balancer**: Internet-facing, multi-AZ
- **Target Group**: Health checks and traffic routing
- **Listener Rules**: HTTP traffic forwarding
- **Health Checks**: Automated instance health monitoring

#### Database Layer ([`database.tf`](infrastructure-automation/database.tf))

- **RDS PostgreSQL**: Managed database service
- **Subnet Group**: Multi-AZ database placement
- **Encryption**: Storage encryption at rest
- **Backup Configuration**: Automated daily backups
- **Monitoring**: Basic CloudWatch metrics

#### Security & Secrets ([`kms.tf`](infrastructure-automation/kms.tf))

- **KMS Key**: Customer-managed encryption key
- **Secrets Manager**: Encrypted database credentials storage
- **IAM Roles**: EC2 access to secrets with least-privilege
- **Random Password**: Secure database password generation

### Web Application

The deployed web application ([`user-data.sh`](infrastructure-automation/user-data.sh)) features:

#### Technology Stack
- **Web Server**: Nginx
- **Runtime**: Amazon Linux 2
- **Security**: AWS Secrets Manager integration
- **Monitoring**: Health check endpoints

#### Features
- **Infrastructure Info**: Displays server details and database status
- **Health Checks**: JSON endpoint for load balancer monitoring
- **Security**: Database credentials via Secrets Manager
- **Logging**: Comprehensive setup and deployment logs

#### Endpoints
```bash
# Main application
http://your-alb-dns-name/

# Health check
http://your-alb-dns-name/health
```

### CI/CD Pipeline

#### GitHub Actions Workflow ([`.github/workflows/terraform-infra.yml`](.github/workflows/terraform-infra.yml))

**Features:**
- **Manual Triggers**: Workflow dispatch with options
- **Plan/Apply/Destroy**: Flexible deployment actions
- **AWS Integration**: Secure credential management
- **Validation**: Terraform format and validation checks
- **Output Display**: Infrastructure endpoints and credentials

**Usage:**

1. **Configure GitHub Secrets:**
```
AWS_ACCESS_KEY_ID     = your-aws-access-key
AWS_SECRET_ACCESS_KEY = your-aws-secret-key
```

2. **Trigger Deployment:**
   - Go to Actions tab in GitHub
   - Select "Infrastructure Deployment"
   - Click "Run workflow"
   - Choose action (plan/apply) and run

3. **Monitor Progress:**
   - View real-time logs in GitHub Actions
   - Check outputs for application URLs
   - Monitor AWS resources in console

### Security Best Practices

#### Network Security
- **Private Subnets**: EC2 instances not directly accessible from internet
- **Security Groups**: Principle of least privilege with layer-4 firewall rules
- **NAT Gateway**: Secure outbound internet access for private instances
- **VPC Isolation**: Custom VPC with controlled network boundaries

#### Data Protection
- **Encryption at Rest**: RDS and Secrets Manager encrypted with KMS
- **Encryption in Transit**: TLS for all communications
- **Secrets Management**: No hardcoded credentials
- **IAM Roles**: Instance profiles with minimal permissions

#### Operational Security
- **SSH Access**: Limited to VPC CIDR block (10.0.0.0/16) via security groups
- **IAM Roles**: EC2 instances use IAM roles for Secrets Manager access
- **Backup**: Automated RDS backups (7-day retention)
- **Monitoring**: Basic CloudWatch metrics for RDS and EC2
- **No Hardcoded Credentials**: Database credentials stored in AWS Secrets Manager

### Monitoring and Troubleshooting

#### Infrastructure Monitoring

**Application Health:**
```bash
# Check application status
curl -s http://$(terraform output -raw load_balancer_dns_name)/health | jq '.'

# Monitor load balancer targets
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)
```

**Database Connectivity:**
```bash
# Test database connection
aws rds describe-db-instances --db-instance-identifier $(terraform output -raw database_identifier)
```

**Secrets Access:**
```bash
# Verify secrets manager
aws secretsmanager get-secret-value --secret-id $(terraform output -raw db_secret_arn)
```
