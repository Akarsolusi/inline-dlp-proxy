#!/bin/bash

# Certificate Authority Generation Script
# Creates a root CA for SSL/TLS interception

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_DIR/certs"
SSL_BUMP_DIR="$PROJECT_DIR/ssl-bump"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create directories
mkdir -p "$CERTS_DIR"
mkdir -p "$SSL_BUMP_DIR"

print_status "Generating CA certificate for HTTPS inspection..."

# Check if CA already exists
if [ -f "$CERTS_DIR/ca.pem" ] && [ -f "$CERTS_DIR/ca.key" ]; then
    print_warning "CA certificate already exists!"
    read -p "Do you want to regenerate it? (yes/no): " answer
    if [ "$answer" != "yes" ]; then
        print_status "Using existing CA certificate"
        exit 0
    fi
    print_warning "Regenerating will invalidate all client trust! Clients will need to reinstall the CA."
fi

# Generate CA private key
print_status "Generating CA private key..."
openssl genrsa -out "$CERTS_DIR/ca.key" 4096

# Generate CA certificate
print_status "Generating CA certificate..."
openssl req -new -x509 -days 3650 -key "$CERTS_DIR/ca.key" -out "$CERTS_DIR/ca.pem" -subj "/C=US/ST=State/L=City/O=DLP Proxy/OU=Security/CN=DLP-Proxy-CA"

# Generate DER format for easier client installation
openssl x509 -in "$CERTS_DIR/ca.pem" -outform DER -out "$CERTS_DIR/ca.crt"

# Set permissions
chmod 600 "$CERTS_DIR/ca.key"
chmod 644 "$CERTS_DIR/ca.pem"
chmod 644 "$CERTS_DIR/ca.crt"

print_status "CA certificate generated successfully!"
echo ""
print_status "Certificate files:"
echo "  - CA Certificate (PEM): $CERTS_DIR/ca.pem"
echo "  - CA Certificate (DER): $CERTS_DIR/ca.crt"
echo "  - CA Private Key:       $CERTS_DIR/ca.key"
echo ""
print_warning "SECURITY WARNING:"
echo "  - Keep ca.key secure! Anyone with this key can intercept HTTPS traffic."
echo "  - Store backups in a secure location."
echo "  - Do not share the private key (.key file)."
echo ""
print_status "Next steps:"
echo "  1. Start the proxy with: ./scripts/manage-proxy.sh start"
echo "  2. Install CA on client servers with: ./scripts/install-ca.sh"
echo ""

# Display CA certificate info
print_status "CA Certificate Information:"
openssl x509 -in "$CERTS_DIR/ca.pem" -noout -text | grep -A 2 "Subject:"
openssl x509 -in "$CERTS_DIR/ca.pem" -noout -text | grep -A 2 "Validity"
