# interview-tasks
Contains solutions for 2 technical tasks as part of my interview process.

## Task 1 - Certificate Expiry Date Checker Script

A Python script that checks and displays the expiration date of SSL/TLS certificates for a set of websites.

### Features

- Checks multiple websites concurrently for performance
- Configurable timeout and website list
- Detailed logging and error handling
- Human-readable output with status indicators
- JSON output for automation
- Docker containerization
- Graceful error handling for network issues

### Prerequisites

- Python 3.11 or higher
- Docker (for containerized execution)

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

3. Configure websites in `config.json`:
```json
{
    "websites": [
        "https://google.com",
        "https://github.com",
        "https://stackoverflow.com",
        "https://python.org",
        "https://sap.com"
    ],
    "timeout": 10,
    "output_format": "table"
}
```

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

3. Run with custom config (mount volume):
```bash
docker run --rm -v $(pwd)/config.json:/app/config.json cert-checker
```

### Output

The script provides:
- Table format output showing URL, hostname, status, expiry date, and days until expiry
- Status indicators: OK, WARNING (expires within 30 days), EXPIRED, ERROR
- Summary statistics
- JSON file output (`cert_results.json`)
- Detailed logs (`cert_checker.log`)
