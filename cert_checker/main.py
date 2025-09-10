#!/usr/bin/env python3
"""
Certificate Expiry Date Checker Script
Checks SSL/TLS certificate expiration dates for a list of websites.
"""

import json
import ssl
import socket
import sys
import requests
import os
from datetime import datetime, timezone
from urllib.parse import urlparse
import logging
from typing import List, Dict, Optional, Tuple
from tabulate import tabulate
import concurrent.futures
import threading

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('cert_checker.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class CertificateChecker:
    """
    A class to check SSL/TLS certificate expiration dates for websites.
    """
    
    def __init__(self, config_file: str = 'config.json'):
        """
        Initialize the CertificateChecker with configuration.
        
        Args:
            config_file (str): Path to the configuration file
        """
        self.config = self._load_config(config_file)
        self.results = []
        self.lock = threading.Lock()
        # Get thresholds from config or use defaults
        self.thresholds = self.config.get('thresholds', {'critical': 7, 'warning': 30})
    
    def _load_config(self, config_file: str) -> Dict:
        """
        Load configuration from JSON file.
        
        Args:
            config_file (str): Path to the configuration file
            
        Returns:
            Dict: Configuration dictionary
            
        Raises:
            FileNotFoundError: If config file doesn't exist
            json.JSONDecodeError: If config file is invalid JSON
        """
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
                logger.info(f"Configuration loaded from {config_file}")
                return config
        except FileNotFoundError:
            logger.error(f"Configuration file {config_file} not found")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in configuration file: {e}")
            raise
    
    def _parse_url(self, url: str) -> Tuple[str, int]:
        """
        Parse URL to extract hostname and port.
        
        Args:
            url (str): URL to parse
            
        Returns:
            Tuple[str, int]: Hostname and port
        """
        parsed = urlparse(url)
        hostname = parsed.hostname or parsed.netloc
        port = parsed.port or (443 if parsed.scheme == 'https' else 80)
        return hostname, port
    
    def _get_certificate_info(self, hostname: str, port: int, timeout: int) -> Optional[Dict]:
        """
        Retrieve SSL certificate information for a given hostname and port.
        
        Args:
            hostname (str): The hostname to check
            port (int): The port to connect to
            timeout (int): Connection timeout in seconds
            
        Returns:
            Optional[Dict]: Certificate information or None if failed
        """
        try:
            # Create SSL context
            context = ssl.create_default_context()
            
            # Connect to the server and get certificate
            with socket.create_connection((hostname, port), timeout=timeout) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    cert = ssock.getpeercert()
                    
            return cert
            
        except socket.timeout:
            logger.error(f"Timeout connecting to {hostname}:{port}")
            return None
        except socket.gaierror as e:
            logger.error(f"DNS resolution failed for {hostname}: {e}")
            return None
        except ssl.SSLError as e:
            logger.error(f"SSL error for {hostname}: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error for {hostname}: {e}")
            return None
    
    def _parse_certificate_date(self, date_string: str) -> datetime:
        """
        Parse certificate date string to datetime object.
        
        Args:
            date_string (str): Date string from certificate
            
        Returns:
            datetime: Parsed datetime object
        """
        return datetime.strptime(date_string, '%b %d %H:%M:%S %Y %Z').replace(tzinfo=timezone.utc)
    
    def _calculate_days_until_expiry(self, expiry_date: datetime) -> int:
        """
        Calculate days until certificate expires.
        
        Args:
            expiry_date (datetime): Certificate expiry date
            
        Returns:
            int: Days until expiry (negative if already expired)
        """
        now = datetime.now(timezone.utc)
        delta = expiry_date - now
        return delta.days
    
    def _determine_status(self, days_until_expiry: int) -> str:
        """
        Determine status based on configurable thresholds.
        
        Args:
            days_until_expiry (int): Days until expiry
            
        Returns:
            str: Status (CRITICAL, WARNING, OK, EXPIRED)
        """
        if days_until_expiry < 0:
            return 'EXPIRED'
        elif days_until_expiry <= self.thresholds['critical']:
            return 'CRITICAL'
        elif days_until_expiry <= self.thresholds['warning']:
            return 'WARNING'
        else:
            return 'OK'
    
    def _check_single_certificate(self, url: str) -> Dict:
        """
        Check certificate for a single URL.
        
        Args:
            url (str): URL to check
            
        Returns:
            Dict: Certificate check result
        """
        logger.info(f"Checking certificate for {url}")
        
        try:
            hostname, port = self._parse_url(url)
            timeout = self.config.get('timeout', 10)
            
            cert_info = self._get_certificate_info(hostname, port, timeout)
            
            if cert_info is None:
                return {
                    'url': url,
                    'hostname': hostname,
                    'status': 'ERROR',
                    'expiry_date': 'N/A',
                    'days_until_expiry': 'N/A',
                    'error': 'Failed to retrieve certificate'
                }
            
            # Parse certificate dates
            expiry_date = self._parse_certificate_date(cert_info['notAfter'])
            days_until_expiry = self._calculate_days_until_expiry(expiry_date)
            
            # Determine status using configurable thresholds
            status = self._determine_status(days_until_expiry)
            
            result = {
                'url': url,
                'hostname': hostname,
                'status': status,
                'expiry_date': expiry_date.strftime('%Y-%m-%d %H:%M:%S UTC'),
                'days_until_expiry': days_until_expiry,
                'error': None
            }
            
            logger.info(f"Certificate for {url} expires on {result['expiry_date']} ({days_until_expiry} days) - Status: {status}")
            return result
            
        except Exception as e:
            logger.error(f"Error checking certificate for {url}: {e}")
            return {
                'url': url,
                'hostname': hostname if 'hostname' in locals() else 'Unknown',
                'status': 'ERROR',
                'expiry_date': 'N/A',
                'days_until_expiry': 'N/A',
                'error': str(e)
            }
    
    def check_certificates(self) -> List[Dict]:
        """
        Check certificates for all URLs in the configuration.
        
        Returns:
            List[Dict]: List of certificate check results
        """
        websites = self.config.get('websites', [])
        
        if not websites:
            logger.warning("No websites found in configuration")
            return []
        
        logger.info(f"Starting certificate checks for {len(websites)} websites")
        
        # Use ThreadPoolExecutor for concurrent certificate checks
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            future_to_url = {
                executor.submit(self._check_single_certificate, url): url 
                for url in websites
            }
            
            results = []
            for future in concurrent.futures.as_completed(future_to_url):
                result = future.result()
                with self.lock:
                    results.append(result)
        
        # Sort results by days until expiry (expired first, then by urgency)
        results.sort(key=lambda x: (
            x['days_until_expiry'] if isinstance(x['days_until_expiry'], int) else float('inf')
        ))
        
        self.results = results
        logger.info(f"Certificate checks completed for {len(results)} websites")
        return results
    
    def display_results(self, results: List[Dict]) -> None:
        """
        Display certificate check results in a formatted table.
        
        Args:
            results (List[Dict]): Certificate check results
        """
        if not results:
            print("No results to display")
            return
        
        # Prepare table data
        headers = ['URL', 'Hostname', 'Status', 'Expiry Date', 'Days Until Expiry']
        table_data = []
        
        for result in results:
            table_data.append([
                result['url'],
                result['hostname'],
                result['status'],
                result['expiry_date'],
                result['days_until_expiry']
            ])
        
        # Display table
        print("\n" + "="*80)
        print("SSL/TLS Certificate Expiry Report")
        print("="*80)
        print(tabulate(table_data, headers=headers, tablefmt='grid'))
        
        # Display summary with configurable thresholds
        total = len(results)
        expired = sum(1 for r in results if r['status'] == 'EXPIRED')
        critical = sum(1 for r in results if r['status'] == 'CRITICAL')
        warning = sum(1 for r in results if r['status'] == 'WARNING')
        ok = sum(1 for r in results if r['status'] == 'OK')
        errors = sum(1 for r in results if r['status'] == 'ERROR')
        
        print(f"\nSummary:")
        print(f"Total certificates checked: {total}")
        print(f"🟢 OK: {ok}")
        print(f"🟡 Warning (≤{self.thresholds['warning']} days): {warning}")
        print(f"🔴 Critical (≤{self.thresholds['critical']} days): {critical}")
        print(f"❌ Expired: {expired}")
        print(f"❗ Errors: {errors}")
        print(f"\nConfigured Thresholds:")
        print(f"Critical: ≤{self.thresholds['critical']} days")
        print(f"Warning: ≤{self.thresholds['warning']} days")
        print("="*80)
    
    def send_slack_webhook_alert(self, results: List[Dict]) -> bool:
        """
        Send Slack webhook alert for critical certificates.
        
        Args:
            results (List[Dict]): Certificate check results
            
        Returns:
            bool: True if webhook sent successfully
        """
        webhook_config = self.config.get('slack_webhook', {})
        
        if not webhook_config.get('enabled', False):
            logger.info("Slack webhook alerting is disabled")
            return False
        
        # Check for critical/expired certificates
        critical_certs = [r for r in results if r['status'] in ['CRITICAL', 'EXPIRED', 'ERROR']]
        warning_certs = [r for r in results if r['status'] == 'WARNING']
        
        # Decide whether to send alert
        should_send = (
            (critical_certs and webhook_config.get('send_on_critical', True)) or
            (warning_certs and webhook_config.get('send_on_warning', False))
        )
        
        if not should_send:
            logger.info("No alerts to send based on configuration")
            return False
        
        try:
            webhook_url = webhook_config.get('url')
            if not webhook_url:
                logger.error("No Slack webhook URL configured")
                return False
            
            # Determine alert color and emoji based on severity
            if critical_certs:
                color = "danger"
                alert_level = "CRITICAL"
                emoji = "🚨"
            elif warning_certs:
                color = "warning"
                alert_level = "WARNING"
                emoji = "⚠️"
            else:
                color = "good"
                alert_level = "INFO"
                emoji = "ℹ️"
            
            # Build the main message
            main_text = f"{emoji} *Certificate Expiry Alert - {alert_level}*"
            
            # Create Slack message payload
            slack_payload = {
                "text": main_text,
                "username": "Certificate Monitor",
                "icon_emoji": ":shield:",
                "attachments": [
                    {
                        "color": color,
                        "title": f"Certificate Monitoring Report",
                        "text": f"Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}",
                        "fields": [
                            {
                                "title": "Total Certificates Checked",
                                "value": str(len(results)),
                                "short": True
                            },
                            {
                                "title": "Critical/Expired",
                                "value": str(len(critical_certs)),
                                "short": True
                            },
                            {
                                "title": "Warning",
                                "value": str(len(warning_certs)),
                                "short": True
                            },
                            {
                                "title": "Thresholds",
                                "value": f"Critical: ≤{self.thresholds['critical']} days, Warning: ≤{self.thresholds['warning']} days",
                                "short": True
                            }
                        ],
                        "footer": "Certificate Monitor",
                        "footer_icon": "https://slack.com/img/favicon.ico",
                        "ts": int(datetime.now().timestamp())
                    }
                ]
            }
            
            # Add critical certificates details
            if critical_certs:
                critical_text = "*CRITICAL/EXPIRED Certificates:*\n"
                for cert in critical_certs[:10]:
                    status_emoji = "🔴" if cert['status'] == 'CRITICAL' else "❌" if cert['status'] == 'EXPIRED' else "❗"
                    critical_text += f"• {status_emoji} *{cert['url']}*: {cert['status']} ({cert['days_until_expiry']} days)\n"
                
                if len(critical_certs) > 10:
                    critical_text += f"\n_... and {len(critical_certs) - 10} more critical certificates_"
                
                slack_payload["attachments"].append({
                    "color": "danger",
                    "title": "Critical Certificates Details",
                    "text": critical_text,
                    "mrkdwn_in": ["text"]
                })
            
            # Add warning certificates details if enabled
            if warning_certs and webhook_config.get('send_on_warning', False):
                warning_text = "*WARNING Certificates:*\n"
                for cert in warning_certs[:5]:
                    warning_text += f"• 🟡 *{cert['url']}*: {cert['status']} ({cert['days_until_expiry']} days)\n"
                
                if len(warning_certs) > 5:
                    warning_text += f"\n_... and {len(warning_certs) - 5} more warning certificates_"
                
                slack_payload["attachments"].append({
                    "color": "warning", 
                    "title": "Warning Certificates Details",
                    "text": warning_text,
                    "mrkdwn_in": ["text"]
                })
            
            # Send webhook
            headers = {'Content-Type': 'application/json'}
            response = requests.post(webhook_url, json=slack_payload, headers=headers, timeout=10)
            response.raise_for_status()
            
            logger.info(f"Slack webhook alert sent successfully")
            return True
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to send Slack webhook alert: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error sending Slack webhook: {e}")
            return False
    
    def save_results_to_file(self, results: List[Dict], filename: str = 'cert_results.json') -> None:
        """
        Save results to a JSON file.
        
        Args:
            results (List[Dict]): Certificate check results
            filename (str): Output filename
        """
        try:
            output_data = {
                'timestamp': datetime.now().isoformat(),
                'total_checked': len(results),
                'thresholds': self.thresholds,
                'results': results
            }
            
            with open(filename, 'w') as f:
                json.dump(output_data, f, indent=2, default=str)
            
            logger.info(f"Results saved to {filename}")
            
        except Exception as e:
            logger.error(f"Error saving results to file: {e}")

def main():
    """
    Main function to run the certificate checker.
    """
    try:
        # Initialize certificate checker
        checker = CertificateChecker()
        
        # Check certificates
        results = checker.check_certificates()
        
        # Display results
        checker.display_results(results)
        
        # Save results to file
        checker.save_results_to_file(results)

        # Send Slack webhook alerts if needed
        checker.send_slack_webhook_alert(results)
        
    except KeyboardInterrupt:
        logger.info("Script interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()