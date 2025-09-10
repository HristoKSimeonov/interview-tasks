#!/usr/bin/env python3
"""
Simple test script for certificate checker
"""

import unittest
from unittest.mock import patch, MagicMock
from main import CertificateChecker
import json
import tempfile
import os
from datetime import datetime, timezone, timedelta

class TestCertificateChecker(unittest.TestCase):
    def setUp(self):
        # Create a temporary config file
        self.test_config = {
            "websites": ["https://google.com"],
            "timeout": 5
        }
        
        self.temp_config = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
        json.dump(self.test_config, self.temp_config)
        self.temp_config.close()
        
        self.checker = CertificateChecker(self.temp_config.name)
    
    def tearDown(self):
        os.unlink(self.temp_config.name)
    
    def test_load_config(self):
        self.assertEqual(self.checker.config['websites'], ["https://google.com"])
        self.assertEqual(self.checker.config['timeout'], 5)
    
    def test_parse_url(self):
        hostname, port = self.checker._parse_url("https://example.com:8443")
        self.assertEqual(hostname, "example.com")
        self.assertEqual(port, 8443)
        
        hostname, port = self.checker._parse_url("https://example.com")
        self.assertEqual(hostname, "example.com")
        self.assertEqual(port, 443)
    
    def test_parse_certificate_date(self):
        # Test certificate date parsing
        date_string = "Jan 15 23:59:59 2025 GMT"
        parsed_date = self.checker._parse_certificate_date(date_string)
        expected_date = datetime(2025, 1, 15, 23, 59, 59, tzinfo=timezone.utc)
        self.assertEqual(parsed_date, expected_date)
    
    def test_calculate_days_until_expiry(self):
        # Test with a future date
        now = datetime.now(timezone.utc)
        future_date = now + timedelta(days=30)
        days = self.checker._calculate_days_until_expiry(future_date)
        self.assertGreaterEqual(days, 29)
        self.assertLessEqual(days, 30)
        
        # Test with past date (expired certificate)
        past_date = now - timedelta(days=5)
        days = self.checker._calculate_days_until_expiry(past_date)
        self.assertLess(days, 0)
        
        # Use a date that is in the future
        near_future = now + timedelta(seconds=10)
        days = self.checker._calculate_days_until_expiry(near_future)
        self.assertGreaterEqual(days, 0)
        self.assertLessEqual(days, 1)
        
        # Test with a specific past date to ensure negative calculation works
        specific_past = now - timedelta(days=10)
        days = self.checker._calculate_days_until_expiry(specific_past)
        self.assertLessEqual(days, -9)
        self.assertGreaterEqual(days, -11)
    
    def test_config_file_not_found(self):
        # Test handling of missing config file
        with self.assertRaises(FileNotFoundError):
            CertificateChecker('nonexistent_config.json')
    
    def test_invalid_json_config(self):
        # Create a temporary file with invalid JSON
        invalid_config = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
        invalid_config.write("{ invalid json }")
        invalid_config.close()
        
        try:
            with self.assertRaises(json.JSONDecodeError):
                CertificateChecker(invalid_config.name)
        finally:
            os.unlink(invalid_config.name)
    
    @patch('main.socket.create_connection')
    @patch('main.ssl.create_default_context')
    def test_get_certificate_info_success(self, mock_ssl_context, mock_socket):
        # Mock successful certificate retrieval
        mock_cert = {
            'notAfter': 'Jan 15 23:59:59 2025 GMT',
            'subject': [['CN', 'example.com']]
        }
        
        mock_ssl_socket = MagicMock()
        mock_ssl_socket.getpeercert.return_value = mock_cert
        
        mock_context = MagicMock()
        mock_context.wrap_socket.return_value.__enter__.return_value = mock_ssl_socket
        mock_ssl_context.return_value = mock_context
        
        mock_socket_conn = MagicMock()
        mock_socket.return_value.__enter__.return_value = mock_socket_conn
        
        result = self.checker._get_certificate_info("example.com", 443, 10)
        self.assertEqual(result, mock_cert)
    
    @patch('main.socket.create_connection')
    @patch('main.ssl.create_default_context')  
    def test_get_certificate_info_timeout(self, mock_ssl_context, mock_socket):
        # Mock timeout scenario
        import socket as sock_module
        mock_socket.side_effect = sock_module.timeout("Connection timed out")
        
        result = self.checker._get_certificate_info("timeout.example.com", 443, 1)
        self.assertIsNone(result)
    
    def test_check_single_certificate_error_handling(self):
        # Test error handling for invalid URL
        result = self.checker._check_single_certificate("invalid-url")
        self.assertEqual(result['status'], 'ERROR')
        self.assertEqual(result['expiry_date'], 'N/A')
        self.assertEqual(result['days_until_expiry'], 'N/A')

if __name__ == '__main__':
    unittest.main()