#!/bin/bash

# Stop All - Complete Proxy Shutdown Script
# Stops the proxy server and shows instructions for clients

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Main script
print_header "STOPPING ENVOY DLP PROXY"
echo ""

# Step 1: Stop the proxy server
print_status "Step 1: Stopping proxy server..."
echo ""

cd "$PROJECT_DIR"

# Check if running via systemd
if systemctl is-active --quiet envoy-dlp 2>/dev/null; then
    print_status "Detected systemd service, stopping..."
    if [ "$EUID" -ne 0 ]; then
        print_warning "Need sudo to stop systemd service"
        sudo systemctl stop envoy-dlp
    else
        systemctl stop envoy-dlp
    fi
    print_status "Systemd service stopped"
else
    # Stop via docker-compose
    if docker-compose ps | grep -q "Up"; then
        print_status "Stopping Docker containers..."
        docker-compose down
        print_status "Docker containers stopped"
    else
        print_warning "No running containers found"
    fi
fi

echo ""
print_status "✓ Proxy server stopped successfully!"
echo ""

# Step 2: Show client removal instructions
print_header "STEP 2: DISABLE PROXY ON CLIENT SERVERS"
echo ""

print_warning "The proxy server is stopped, but clients are still configured to use it."
print_warning "Run these commands on EACH client server to restore normal operation:"
echo ""

echo -e "${BLUE}On each client server:${NC}"
echo ""
echo "  1. Remove proxy configuration:"
echo -e "     ${GREEN}sudo ./configure-client.sh remove${NC}"
echo ""
echo "  2. Logout and login again, OR reload environment:"
echo -e "     ${GREEN}unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY${NC}"
echo ""
echo "  3. Verify proxy is disabled:"
echo -e "     ${GREEN}env | grep -i proxy${NC}  # Should return nothing"
echo -e "     ${GREEN}curl -v http://www.google.com${NC}  # Should connect directly"
echo ""

# Step 3: Optional CA removal
print_header "OPTIONAL: REMOVE CA CERTIFICATES FROM CLIENTS"
echo ""

print_status "If you also want to remove the CA certificate (for HTTPS inspection):"
echo ""
echo "  On Ubuntu/Debian clients:"
echo -e "     ${GREEN}sudo rm /usr/local/share/ca-certificates/dlp-proxy-ca.crt${NC}"
echo -e "     ${GREEN}sudo update-ca-certificates --fresh${NC}"
echo ""
echo "  On RHEL/CentOS/Fedora clients:"
echo -e "     ${GREEN}sudo rm /etc/pki/ca-trust/source/anchors/dlp-proxy-ca.crt${NC}"
echo -e "     ${GREEN}sudo update-ca-trust${NC}"
echo ""

# Step 4: Status summary
print_header "CURRENT STATUS"
echo ""

print_status "Server Status:"
if systemctl is-active --quiet envoy-dlp 2>/dev/null; then
    echo "  Systemd Service: ${RED}Still Running${NC} (Failed to stop?)"
elif docker-compose ps 2>/dev/null | grep -q "Up"; then
    echo "  Docker Containers: ${RED}Still Running${NC} (Failed to stop?)"
else
    echo "  Proxy Server: ${GREEN}Stopped${NC} ✓"
fi
echo ""

print_status "Containers:"
docker-compose ps 2>/dev/null || echo "  No containers running"
echo ""

print_status "Ports Released:"
netstat -tulpn 2>/dev/null | grep -E ':(3128|8080|9901|3000)' || echo "  All proxy ports released ✓"
echo ""

# Step 5: Show restart instructions
print_header "TO RESTART LATER"
echo ""

echo "  On proxy server:"
echo -e "     ${GREEN}./scripts/manage-proxy.sh start${NC}"
echo ""
echo "  On each client server:"
echo -e "     ${GREEN}sudo ./configure-client.sh configure PROXY_IP 3128${NC}"
echo ""

print_status "Done! Proxy has been stopped on this server."
print_warning "Don't forget to disable proxy on client servers!"
