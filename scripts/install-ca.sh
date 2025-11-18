#!/bin/bash

# Client CA Installation Script
# Installs the DLP Proxy CA certificate on client systems

set -e

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script requires root privileges. Please run with sudo."
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

# Install CA on Ubuntu/Debian
install_ca_debian() {
    local CA_FILE="$1"

    print_status "Installing CA certificate on Debian/Ubuntu..."

    # Copy CA certificate
    cp "$CA_FILE" /usr/local/share/ca-certificates/dlp-proxy-ca.crt

    # Update CA certificates
    update-ca-certificates

    print_status "CA certificate installed successfully!"
}

# Install CA on RHEL/CentOS/Fedora
install_ca_rhel() {
    local CA_FILE="$1"

    print_status "Installing CA certificate on RHEL/CentOS/Fedora..."

    # Copy CA certificate
    cp "$CA_FILE" /etc/pki/ca-trust/source/anchors/dlp-proxy-ca.crt

    # Update CA trust
    update-ca-trust

    print_status "CA certificate installed successfully!"
}

# Verify installation
verify_installation() {
    print_status "Verifying CA installation..."

    if openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/dlp-proxy-ca.pem 2>/dev/null; then
        print_status "CA certificate verification successful!"
        return 0
    else
        print_warning "Could not verify using standard method, but certificate should be installed"
        return 0
    fi
}

# Display usage
usage() {
    cat << EOF
CA Certificate Installation Script

Usage: $0 [CA_CERTIFICATE_FILE]

If no file is provided, you can:
  1. Download from proxy server:
     scp user@proxy-server:/path/to/envoy-dlp-proxy/certs/ca.crt ./

  2. Or download via HTTP (if web server is set up):
     curl http://proxy-server:3000/ca.crt -o ca.crt

Then run: sudo $0 ca.crt

Examples:
    sudo $0 /tmp/ca.crt              # Install from local file
    sudo $0 ~/Downloads/ca.crt       # Install from downloads

After installation:
    - System will trust certificates signed by the DLP Proxy
    - HTTPS inspection will work through the proxy
    - Some apps may still reject the proxy (certificate pinning)

EOF
}

# Main script
main() {
    if [ -z "${1:-}" ] || [ "$1" == "help" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        usage
        exit 0
    fi

    check_root
    detect_os

    CA_FILE="$1"

    if [ ! -f "$CA_FILE" ]; then
        print_error "CA certificate file not found: $CA_FILE"
        echo ""
        usage
        exit 1
    fi

    # Verify it's a valid certificate
    if ! openssl x509 -in "$CA_FILE" -noout 2>/dev/null; then
        print_error "Invalid certificate file: $CA_FILE"
        exit 1
    fi

    print_status "Certificate Information:"
    openssl x509 -in "$CA_FILE" -noout -subject -issuer -dates
    echo ""

    print_warning "You are about to install a CA certificate that allows HTTPS interception."
    print_warning "This will allow the proxy server to decrypt and inspect all HTTPS traffic."
    read -p "Do you want to continue? (yes/no): " answer

    if [ "$answer" != "yes" ]; then
        print_status "Installation cancelled"
        exit 0
    fi

    case "$OS" in
        ubuntu|debian)
            install_ca_debian "$CA_FILE"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            install_ca_rhel "$CA_FILE"
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_status "Please install the CA certificate manually for your OS"
            exit 1
            ;;
    esac

    verify_installation

    echo ""
    print_status "Installation complete!"
    print_status "The system now trusts the DLP Proxy CA certificate."
    echo ""
    print_status "Next steps:"
    echo "  1. Configure this system to use the proxy:"
    echo "     sudo ./configure-client.sh configure PROXY_IP 3128"
    echo "  2. Test HTTPS interception:"
    echo "     curl -v https://www.google.com"
    echo ""
    print_warning "Note: Some applications with certificate pinning may still fail."
}

main "$@"
