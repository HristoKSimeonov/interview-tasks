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