# OCI8 Installer for Ubuntu 24.04

Automated installation script for OCI8 extension on Ubuntu 24.04 with PHP 8.2-8.5.

## About

This installer script is based on the tutorial from: https://gist.github.com/syahzul/f88680d3ada2ff0337013947a9029e33

## Usage

Run the installer script with sudo:

```bash
wget -O oci8-installer.sh "https://raw.githubusercontent.com/syahzul/oci-installer-ubuntu/refs/heads/main/install.sh"; bash oci8-installer.sh
```

The script will:
- Detect installed PHP versions (8.2-8.5)
- Allow you to select which PHP version to install OCI8 for
- Automatically download and install Oracle Instant Client
- Install and configure OCI8 extension via PECL
- Restart PHP-FPM service if available

## Requirements

- Ubuntu 24.04
- PHP 8.2, 8.3 or 8.4 installed
- Root or sudo access
- Internet connection (for downloading Oracle Instant Client)

## Testing

After installation, verify OCI8 is loaded:

```bash
php8.3 -m | grep oci8
```

Or test with PHP code:

```php
<?php
if (function_exists('oci_connect')) {
    echo 'OCI8 is working!';
} else {
    echo 'OCI8 is not working!';
}
```
