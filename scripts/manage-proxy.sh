#!/bin/bash

# Envoy DLP Proxy Management Script
# This script helps manage the Envoy DLP proxy service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="envoy-dlp.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This operation requires root privileges. Please run with sudo."
        exit 1
    fi
}

# Function to install the service
install_service() {
    check_root
    print_status "Installing Envoy DLP Proxy service..."

    # Create logs directory
    mkdir -p "$PROJECT_DIR/logs"
    chmod 755 "$PROJECT_DIR/logs"

    # Copy service file
    cp "$SCRIPT_DIR/$SERVICE_NAME" "$SERVICE_PATH"

    # Update WorkingDirectory in service file
    sed -i "s|WorkingDirectory=.*|WorkingDirectory=$PROJECT_DIR|g" "$SERVICE_PATH"

    # Reload systemd
    systemctl daemon-reload

    print_status "Service installed successfully!"
    print_status "Use 'sudo systemctl start envoy-dlp' to start the service"
    print_status "Use 'sudo systemctl enable envoy-dlp' to enable on boot"
}

# Function to uninstall the service
uninstall_service() {
    check_root
    print_status "Uninstalling Envoy DLP Proxy service..."

    # Stop service if running
    systemctl stop envoy-dlp 2>/dev/null || true

    # Disable service
    systemctl disable envoy-dlp 2>/dev/null || true

    # Remove service file
    rm -f "$SERVICE_PATH"

    # Reload systemd
    systemctl daemon-reload

    print_status "Service uninstalled successfully!"
}

# Function to start the proxy
start_proxy() {
    print_status "Starting Envoy DLP Proxy..."

    if systemctl is-active --quiet envoy-dlp; then
        print_warning "Proxy is already running"
        return
    fi

    if [ -f "$SERVICE_PATH" ]; then
        check_root
        systemctl start envoy-dlp
    else
        cd "$PROJECT_DIR"
        docker-compose up -d
    fi

    print_status "Proxy started successfully!"
    print_status "HTTP Proxy: http://localhost:8080"
    print_status "HTTPS Proxy: http://localhost:8443"
    print_status "Admin Interface: http://localhost:9901"
    print_status "Frontend Dashboard: http://localhost:3000"
}

# Function to stop the proxy
stop_proxy() {
    print_status "Stopping Envoy DLP Proxy..."

    if [ -f "$SERVICE_PATH" ] && systemctl is-active --quiet envoy-dlp; then
        check_root
        systemctl stop envoy-dlp
    else
        cd "$PROJECT_DIR"
        docker-compose down
    fi

    print_status "Proxy stopped successfully!"
}

# Function to restart the proxy
restart_proxy() {
    print_status "Restarting Envoy DLP Proxy..."
    stop_proxy
    sleep 2
    start_proxy
}

# Function to show status
show_status() {
    print_status "Checking Envoy DLP Proxy status..."
    echo ""

    if [ -f "$SERVICE_PATH" ]; then
        systemctl status envoy-dlp --no-pager || true
    else
        cd "$PROJECT_DIR"
        docker-compose ps
    fi
}

# Function to show logs
show_logs() {
    print_status "Showing Envoy DLP Proxy logs..."

    if [ -f "$SERVICE_PATH" ] && systemctl is-active --quiet envoy-dlp; then
        journalctl -u envoy-dlp -f
    else
        cd "$PROJECT_DIR"
        docker-compose logs -f
    fi
}

# Function to show DLP alerts
show_alerts() {
    print_status "Showing DLP alerts..."

    if [ -f "$PROJECT_DIR/logs/dlp_alerts.log" ]; then
        tail -f "$PROJECT_DIR/logs/dlp_alerts.log"
    else
        print_warning "No DLP alerts file found. The proxy may not have detected any sensitive data yet."
    fi
}

# Function to display usage
usage() {
    cat << EOF
Envoy DLP Proxy Management Script

Usage: $0 [COMMAND]

Commands:
    install         Install the systemd service
    uninstall       Uninstall the systemd service
    start           Start the proxy
    stop            Stop the proxy
    restart         Restart the proxy
    status          Show proxy status
    logs            Show proxy logs (follows)
    alerts          Show DLP alerts (follows)
    help            Show this help message

Examples:
    $0 install          # Install as systemd service (requires sudo)
    $0 start            # Start the proxy
    $0 alerts           # Monitor DLP alerts in real-time

EOF
}

# Main script logic
case "${1:-}" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    start)
        start_proxy
        ;;
    stop)
        stop_proxy
        ;;
    restart)
        restart_proxy
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    alerts)
        show_alerts
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
