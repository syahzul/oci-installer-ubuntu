#!/bin/bash

# Script to install OCI8 on Ubuntu 24.04 with PHP 8.2-8.5
# Author: Syahril Zulkefli <syahril@zakat.com.my>
# Date: 2025-12-04

set -e  # Exit on error

echo "=========================================="
echo "OCI8 Installation Script for Ubuntu 24.04"
echo "Oracle Instant Client: 23.26.0.0.0"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Function to check if PHP version is installed
check_php_version() {
    local version=$1
    if command -v php${version} &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Detect installed PHP versions
echo "Detecting installed PHP versions..."
AVAILABLE_VERSIONS=()
for version in 8.2 8.3 8.4 8.5; do
    if check_php_version $version; then
        AVAILABLE_VERSIONS+=($version)
        echo "  ✓ PHP $version detected"
    fi
done

echo ""

# Check if any PHP version is installed
if [ ${#AVAILABLE_VERSIONS[@]} -eq 0 ]; then
    echo "Error: No PHP versions (8.2-8.5) found on this server."
    echo "Please install PHP first before running this script."
    exit 1
fi

# Ask user to select PHP version
echo "Available PHP versions:"
for i in "${!AVAILABLE_VERSIONS[@]}"; do
    echo "  $((i+1)). PHP ${AVAILABLE_VERSIONS[$i]}"
done
echo ""

# If only one version available, use it automatically
if [ ${#AVAILABLE_VERSIONS[@]} -eq 1 ]; then
    PHP_VERSION=${AVAILABLE_VERSIONS[0]}
    echo "Only one PHP version detected. Using PHP $PHP_VERSION"
else
    # Multiple versions available, ask user to choose
    while true; do
        read -p "Select PHP version (1-${#AVAILABLE_VERSIONS[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#AVAILABLE_VERSIONS[@]} ]; then
            PHP_VERSION=${AVAILABLE_VERSIONS[$((choice-1))]}
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

echo ""
echo "Selected PHP version: $PHP_VERSION"
echo ""

# Confirm installation
read -p "Continue with installation? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""

# Step 1: Install dependencies
echo "[1/7] Installing dependencies..."
apt update
apt install -y libaio1t64 unzip php${PHP_VERSION}-dev wget

# Step 2: Create symlink for libaio
echo "[2/7] Creating symlink for libaio..."
if [ ! -f /usr/lib/x86_64-linux-gnu/libaio.so.1 ]; then
    ln -s /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/x86_64-linux-gnu/libaio.so.1
    echo "Symlink created successfully"
else
    echo "Symlink already exists, skipping..."
fi

# Step 3: Create Oracle directory
echo "[3/7] Creating Oracle directory..."
mkdir -p /opt/oracle
cd /opt/oracle

# Step 4: Download Oracle Instant Client files
echo "[4/7] Downloading Oracle Instant Client files..."
if [ ! -f instantclient-basic-linux.x64-23.26.0.0.0.zip ]; then
    wget https://download.oracle.com/otn_software/linux/instantclient/2326000/instantclient-basic-linux.x64-23.26.0.0.0.zip
else
    echo "Basic package already downloaded, skipping..."
fi

if [ ! -f instantclient-sdk-linux.x64-23.26.0.0.0.zip ]; then
    wget https://download.oracle.com/otn_software/linux/instantclient/2326000/instantclient-sdk-linux.x64-23.26.0.0.0.zip
else
    echo "SDK package already downloaded, skipping..."
fi

# Step 5: Extract files
echo "[5/7] Extracting Oracle Instant Client files..."
if [ ! -d /opt/oracle/instantclient_23_26 ]; then
    unzip -q instantclient-basic-linux.x64-23.26.0.0.0.zip
    unzip -q instantclient-sdk-linux.x64-23.26.0.0.0.zip
    echo "Files extracted successfully"
else
    echo "Instant Client already extracted, skipping..."
fi

# Step 6: Configure ldconfig
echo "[6/7] Configuring ldconfig..."
echo /opt/oracle/instantclient_23_26 > /etc/ld.so.conf.d/oracle-instantclient.conf
ldconfig

# Step 7: Install OCI8 via PECL
echo "[7/7] Installing OCI8 extension for PHP ${PHP_VERSION}..."

# Check if OCI8 is already installed for this PHP version
if php${PHP_VERSION} -m 2>/dev/null | grep -q oci8; then
    echo "OCI8 already installed for PHP ${PHP_VERSION}, skipping..."
else
    # Install OCI8
    echo instantclient,/opt/oracle/instantclient_23_26 | pecl install oci8
    
    # Enable OCI8 extension
    echo "extension=oci8.so" > /etc/php/${PHP_VERSION}/mods-available/oci8.ini
    phpenmod -v ${PHP_VERSION} oci8
    
    # Restart PHP-FPM if service exists
    if systemctl list-units --full -all | grep -q "php${PHP_VERSION}-fpm.service"; then
        systemctl restart php${PHP_VERSION}-fpm.service
        echo "PHP-FPM ${PHP_VERSION} restarted"
    else
        echo "PHP-FPM ${PHP_VERSION} service not found, skipping restart..."
    fi
    
    echo "OCI8 installed and enabled successfully for PHP ${PHP_VERSION}"
fi

echo ""
echo "=========================================="
echo "Installation completed!"
echo "=========================================="
echo ""
echo "Testing OCI8 installation for PHP ${PHP_VERSION}..."
if php${PHP_VERSION} -m 2>/dev/null | grep -q oci8; then
    echo "✓ OCI8 is successfully installed and loaded for PHP ${PHP_VERSION}!"
else
    echo "✗ OCI8 installation failed. Please check the logs above."
    exit 1
fi

echo ""
echo "To check OCI8 status: php${PHP_VERSION} -m | grep oci8"