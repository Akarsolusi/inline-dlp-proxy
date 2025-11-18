#!/bin/bash

# Client Configuration Script
# Run this on client servers to configure them to use the Envoy DLP Proxy

set -e

# Colors for output
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

# Function to configure system-wide proxy
configure_proxy() {
    local PROXY_HOST="$1"
    local PROXY_PORT="${2:-3128}"
    local PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

    print_status "Configuring system to use proxy at ${PROXY_URL}..."

    # Backup existing proxy configuration
    if [ -f /etc/environment ]; then
        cp /etc/environment /etc/environment.backup.$(date +%Y%m%d_%H%M%S)
    fi

    # Configure environment variables
    cat >> /etc/environment << EOF

# Envoy DLP Proxy Configuration (added $(date))
http_proxy="${PROXY_URL}"
https_proxy="${PROXY_URL}"
HTTP_PROXY="${PROXY_URL}"
HTTPS_PROXY="${PROXY_URL}"
no_proxy="localhost,127.0.0.1,::1"
NO_PROXY="localhost,127.0.0.1,::1"
EOF

    # Configure apt to use proxy
    cat > /etc/apt/apt.conf.d/95proxies << EOF
Acquire::http::proxy "${PROXY_URL}";
Acquire::https::proxy "${PROXY_URL}";
EOF

    print_status "System proxy configured successfully!"
    print_warning "You may need to logout and login again for all changes to take effect"
}

# Function to remove proxy configuration
remove_proxy() {
    print_status "Removing proxy configuration..."

    check_root

    local CLEANUP_COUNT=0

    # 1. Remove from /etc/environment
    if [ -f /etc/environment ]; then
        if grep -q "# Envoy DLP Proxy Configuration" /etc/environment; then
            sed -i '/# Envoy DLP Proxy Configuration/,/NO_PROXY=/d' /etc/environment
            print_status "✓ Removed proxy from /etc/environment"
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        fi
    fi

    # 2. Remove APT proxy configuration
    if [ -f /etc/apt/apt.conf.d/95proxies ]; then
        rm -f /etc/apt/apt.conf.d/95proxies
        print_status "✓ Removed APT proxy configuration"
        CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
    fi

    # 3. Remove Docker proxy configuration
    if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
        rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
        if systemctl is-active --quiet docker; then
            systemctl daemon-reload
            systemctl restart docker
            print_status "✓ Removed Docker proxy configuration and restarted Docker"
        else
            systemctl daemon-reload
            print_status "✓ Removed Docker proxy configuration"
        fi
        CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
    fi

    # 4. Remove from /etc/profile.d/ if exists
    if [ -f /etc/profile.d/proxy.sh ]; then
        rm -f /etc/profile.d/proxy.sh
        print_status "✓ Removed /etc/profile.d/proxy.sh"
        CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
    fi

    # 5. Create unset script for current shell sessions
    UNSET_SCRIPT="/tmp/unset_proxy_$(date +%s).sh"
    cat > "$UNSET_SCRIPT" << 'EOF'
#!/bin/bash
# Unset proxy variables in current shell
unset HTTP_PROXY
unset HTTPS_PROXY
unset http_proxy
unset https_proxy
unset NO_PROXY
unset no_proxy
unset FTP_PROXY
unset ftp_proxy
echo "Proxy variables unset in current shell"
EOF
    chmod +x "$UNSET_SCRIPT"

    echo ""
    print_status "Proxy configuration removed successfully! (${CLEANUP_COUNT} items cleaned)"
    echo ""
    print_warning "To apply changes immediately in your current terminal:"
    echo -e "  ${YELLOW}source ${UNSET_SCRIPT}${NC}"
    echo ""
    print_warning "Or close this terminal and open a new one"
    echo ""
    print_status "Verification:"
    echo "  After sourcing, run: env | grep -i proxy"
    echo "  Should return nothing (or only system defaults)"
    echo ""

    # 6. Verify cleanup
    print_status "Checking for remaining proxy settings..."
    local REMAINING=0

    if grep -qi "proxy" /etc/environment 2>/dev/null; then
        print_warning "Some proxy settings remain in /etc/environment"
        REMAINING=$((REMAINING + 1))
    fi

    if [ -f /etc/apt/apt.conf.d/95proxies ]; then
        print_warning "APT proxy config still exists"
        REMAINING=$((REMAINING + 1))
    fi

    if [ $REMAINING -eq 0 ]; then
        print_status "✓ All system proxy configurations removed successfully"
    fi
}

# Function to test proxy connection
test_proxy() {
    local PROXY_HOST="$1"
    local PROXY_PORT="${2:-3128}"
    local PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

    print_status "Testing proxy connection to ${PROXY_URL}..."

    if curl -x "${PROXY_URL}" -s -o /dev/null -w "%{http_code}" http://www.google.com | grep -q "200"; then
        print_status "Proxy connection test successful!"
        return 0
    else
        print_error "Proxy connection test failed!"
        return 1
    fi
}

# Function to show current proxy configuration
show_config() {
    print_status "Current proxy configuration:"
    echo ""

    if env | grep -i proxy; then
        echo ""
    else
        print_warning "No proxy environment variables set"
    fi

    if [ -f /etc/apt/apt.conf.d/95proxies ]; then
        echo "APT proxy configuration:"
        cat /etc/apt/apt.conf.d/95proxies
    fi
}

# Function to configure Docker to use proxy
configure_docker_proxy() {
    local PROXY_HOST="$1"
    local PROXY_PORT="${2:-3128}"
    local PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

    print_status "Configuring Docker to use proxy..."

    check_root

    mkdir -p /etc/systemd/system/docker.service.d

    cat > /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=${PROXY_URL}"
Environment="HTTPS_PROXY=${PROXY_URL}"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF

    systemctl daemon-reload
    systemctl restart docker

    print_status "Docker proxy configured successfully!"
}

# Function to display usage
usage() {
    cat << EOF
Client Proxy Configuration Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    configure <proxy_host> [port]   Configure system to use proxy
                                    (default port: 3128)
    remove                          Remove proxy configuration
    test <proxy_host> [port]        Test proxy connection
    show                            Show current proxy configuration
    docker <proxy_host> [port]      Configure Docker to use proxy
    help                            Show this help message

Examples:
    $0 configure 192.168.1.100          # Configure proxy at 192.168.1.100:8080
    $0 configure 192.168.1.100 8080     # Configure proxy with explicit port
    $0 test 192.168.1.100               # Test proxy connection
    $0 remove                           # Remove proxy configuration
    $0 docker 192.168.1.100             # Configure Docker to use proxy

Note: Most commands require root privileges (use sudo)

EOF
}

# Main script logic
case "${1:-}" in
    configure)
        if [ -z "${2:-}" ]; then
            print_error "Proxy host is required"
            echo ""
            usage
            exit 1
        fi
        check_root
        configure_proxy "$2" "${3:-3128}"
        ;;
    remove)
        remove_proxy
        ;;
    test)
        if [ -z "${2:-}" ]; then
            print_error "Proxy host is required"
            echo ""
            usage
            exit 1
        fi
        test_proxy "$2" "${3:-3128}"
        ;;
    show)
        show_config
        ;;
    docker)
        if [ -z "${2:-}" ]; then
            print_error "Proxy host is required"
            echo ""
            usage
            exit 1
        fi
        configure_docker_proxy "$2" "${3:-3128}"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        print_error "Unknown command: ${1:-}"
        echo ""
        usage
        exit 1
        ;;
esac

exit 0
