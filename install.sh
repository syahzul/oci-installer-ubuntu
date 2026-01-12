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

# Function to check if OCI8 is installed for a PHP version
check_oci8_installed() {
    local version=$1
    if php${version} -m 2>/dev/null | grep -q oci8; then
        return 0
    else
        return 1
    fi
}

# Function to check if Oracle Instant Client is properly extracted
check_oracle_extraction() {
    # Check if directory exists
    if [ ! -d /opt/oracle/instantclient_23_26 ]; then
        return 1
    fi
    
    # Check if SDK header directory exists
    if [ ! -d /opt/oracle/instantclient_23_26/sdk ]; then
        return 1
    fi
    
    # Check if essential files exist
    if [ ! -f /opt/oracle/instantclient_23_26/libclntsh.so ]; then
        return 1
    fi
    
    # Check if SDK header files exist
    if [ ! -f /opt/oracle/instantclient_23_26/sdk/include/oci.h ]; then
        return 1
    fi
    
    return 0
}

# Function to check if Oracle Instant Client is already set up
check_oracle_setup() {
    local all_ok=true
    
    # Check if directory exists and properly extracted
    if ! check_oracle_extraction; then
        all_ok=false
    fi
    
    # Check if ldconfig is configured
    if [ ! -f /etc/ld.so.conf.d/oracle-instantclient.conf ]; then
        all_ok=false
    fi
    
    # Check if libraries are accessible
    if ! ldconfig -p | grep -q instantclient_23_26; then
        all_ok=false
    fi
    
    if [ "$all_ok" = true ]; then
        return 0
    else
        return 1
    fi
}

# Verify Oracle Instant Client setup at the beginning
echo "Verifying Oracle Instant Client setup..."
if check_oracle_setup; then
    ORACLE_ALREADY_SETUP=true
    echo "✓ Oracle Instant Client 23.26 is already set up"
    echo "  - Directory: /opt/oracle/instantclient_23_26"
    echo "  - SDK headers: present"
    echo "  - ldconfig: configured"
    echo "  - Libraries: accessible"
    echo ""
    echo "Steps 3-6 will be skipped."
else
    ORACLE_ALREADY_SETUP=false
    echo "✗ Oracle Instant Client not found or incomplete setup"
    echo "  Steps 3-6 will be executed to set up Oracle Instant Client."
fi
echo ""

# Detect installed PHP versions and check OCI8 status
echo "Detecting installed PHP versions and OCI8 status..."
AVAILABLE_VERSIONS=()
INSTALLED_VERSIONS=()

for version in 8.2 8.3 8.4 8.5; do
    if check_php_version $version; then
        if check_oci8_installed $version; then
            INSTALLED_VERSIONS+=($version)
            echo "  ✓ PHP $version detected - OCI8 already installed"
        else
            AVAILABLE_VERSIONS+=($version)
            echo "  ✓ PHP $version detected - OCI8 not installed"
        fi
    fi
done

echo ""

# Check if any PHP version is installed
if [ ${#AVAILABLE_VERSIONS[@]} -eq 0 ] && [ ${#INSTALLED_VERSIONS[@]} -eq 0 ]; then
    echo "Error: No PHP versions (8.2-8.5) found on this server."
    echo "Please install PHP first before running this script."
    exit 1
fi

# Check if all PHP versions already have OCI8 installed
if [ ${#AVAILABLE_VERSIONS[@]} -eq 0 ]; then
    echo "All detected PHP versions already have OCI8 installed:"
    for version in "${INSTALLED_VERSIONS[@]}"; do
        echo "  - PHP $version"
    done
    echo ""
    echo "Nothing to install. Exiting."
    exit 0
fi

# Ask user to select PHP version
echo "Available PHP versions for OCI8 installation:"
for i in "${!AVAILABLE_VERSIONS[@]}"; do
    echo "  $((i+1)). PHP ${AVAILABLE_VERSIONS[$i]}"
done
echo ""

# If only one version available, use it automatically
if [ ${#AVAILABLE_VERSIONS[@]} -eq 1 ]; then
    PHP_VERSION=${AVAILABLE_VERSIONS[0]}
    echo "Only one PHP version needs OCI8. Using PHP $PHP_VERSION"
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
echo "[1/8] Installing dependencies..."
apt update
apt install -y libaio1t64 unzip php${PHP_VERSION}-dev wget build-essential

# Step 2: Create symlink for libaio
echo "[2/8] Creating symlink for libaio..."
if [ ! -f /usr/lib/x86_64-linux-gnu/libaio.so.1 ]; then
    ln -s /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/x86_64-linux-gnu/libaio.so.1
    echo "Symlink created successfully"
else
    echo "Symlink already exists, skipping..."
fi

# Steps 3-6: Oracle Instant Client setup (skip if already set up)
if [ "$ORACLE_ALREADY_SETUP" = false ]; then
    # Step 3: Create Oracle directory
    echo "[3/8] Creating Oracle directory..."
    mkdir -p /opt/oracle
    cd /opt/oracle

    # Step 4: Download Oracle Instant Client files
    echo "[4/8] Downloading Oracle Instant Client files..."
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
    echo "[5/8] Extracting Oracle Instant Client files..."
    
    # Remove incomplete extraction if exists
    if [ -d /opt/oracle/instantclient_23_26 ]; then
        if ! check_oracle_extraction; then
            echo "Removing incomplete extraction..."
            rm -rf /opt/oracle/instantclient_23_26
        fi
    fi
    
    # Extract if directory doesn't exist or was incomplete
    if [ ! -d /opt/oracle/instantclient_23_26 ]; then
        echo "Extracting basic package..."
        unzip -o -q instantclient-basic-linux.x64-23.26.0.0.0.zip
        
        echo "Extracting SDK package..."
        unzip -o -q instantclient-sdk-linux.x64-23.26.0.0.0.zip
        
        # Verify extraction
        if check_oracle_extraction; then
            echo "Files extracted successfully"
        else
            echo "Error: Extraction incomplete or corrupted"
            echo "Please check the zip files and try again"
            exit 1
        fi
    else
        echo "Instant Client already extracted and verified, skipping..."
    fi

    # Step 6: Configure ldconfig
    echo "[6/8] Configuring ldconfig..."
    echo /opt/oracle/instantclient_23_26 > /etc/ld.so.conf.d/oracle-instantclient.conf
    ldconfig
    echo "ldconfig configured successfully"
else
    echo "[3/8] Skipping Oracle directory creation (already exists)"
    echo "[4/8] Skipping Oracle Instant Client download (already downloaded)"
    echo "[5/8] Skipping Oracle Instant Client extraction (already extracted)"
    echo "[6/8] Skipping ldconfig configuration (already configured)"
fi

# Step 7: Download OCI8 tarball from PECL
echo "[7/8] Downloading OCI8 tarball from PECL..."
cd /tmp

OCI8_VERSION="3.4.1"
if [ ! -f oci8-${OCI8_VERSION}.tgz ]; then
    wget https://pecl.php.net/get/oci8-${OCI8_VERSION}.tgz
else
    echo "Extension file already downloaded, skipping..."
fi

# Extract tarball
if [ -d oci8-${OCI8_VERSION} ]; then
    rm -rf oci8-${OCI8_VERSION}
fi
tar -xzf oci8-${OCI8_VERSION}.tgz
cd oci8

# Step 8: Compile and install OCI8 for selected PHP version
echo "[8/8] Compiling and installing OCI8 extension for PHP ${PHP_VERSION}..."

# Clean previous builds
make clean 2>/dev/null || true

# Run phpize
echo "Running phpize for PHP ${PHP_VERSION}..."
/usr/bin/phpize${PHP_VERSION} --clean 2>/dev/null || true
/usr/bin/phpize${PHP_VERSION}

# Configure with Oracle Instant Client
echo "Configuring OCI8..."
./configure --with-oci8=shared,instantclient,/opt/oracle/instantclient_23_26 --with-php-config=/usr/bin/php-config${PHP_VERSION}

# Compile
echo "Compiling OCI8..."
make

# Install
echo "Installing OCI8..."
make install

# Enable OCI8 extension
echo "Enabling OCI8 extension..."
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

# Cleanup
echo ""
echo "Cleaning up temporary files..."
cd /tmp
rm -rf oci8-${OCI8_VERSION}

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

# Show summary if there are other PHP versions with OCI8 already installed
if [ ${#INSTALLED_VERSIONS[@]} -gt 0 ]; then
    echo ""
    echo "Note: The following PHP versions already have OCI8 installed:"
    for version in "${INSTALLED_VERSIONS[@]}"; do
        echo "  - PHP $version"
    done
fi
