#!/bin/bash

###############################################################################
# ThingsBoard Location Tracking Setup Script
#
# This script automates the setup and management of ThingsBoard CE for
# multi-device location tracking on Ubuntu.
#
# Usage:
#   ./setup_thingsboard.sh install    # Install ThingsBoard and dependencies
#   ./setup_thingsboard.sh start      # Start ThingsBoard service
#   ./setup_thingsboard.sh stop       # Stop ThingsBoard service
#   ./setup_thingsboard.sh status     # Check service status
#   ./setup_thingsboard.sh logs       # View service logs
#   ./setup_thingsboard.sh test       # Test telemetry endpoint
###############################################################################

set -e

# Configuration
TB_VERSION="3.6.4"
TB_PORT="8081"
POSTGRES_DB="thingsboard"
POSTGRES_USER="postgres"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Install Java 11
install_java() {
    log_info "Installing OpenJDK 11..."
    apt-get update
    apt-get install -y openjdk-11-jdk
    
    # Set Java 11 as default
    update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java
    
    java -version
    log_info "Java 11 installed successfully"
}

# Install PostgreSQL 16
install_postgresql() {
    log_info "Installing PostgreSQL 16..."
    
    # Add PostgreSQL repository
    apt-get install -y wget ca-certificates
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    
    apt-get update
    apt-get install -y postgresql-16
    
    # Start PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    log_info "PostgreSQL 16 installed successfully"
}

# Setup PostgreSQL database
setup_database() {
    log_info "Setting up ThingsBoard database..."
    
    # Create database and user
    sudo -u postgres psql -c "CREATE DATABASE ${POSTGRES_DB};"
    sudo -u postgres psql -c "CREATE USER thingsboard WITH PASSWORD 'thingsboard';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO thingsboard;"
    
    log_info "Database setup complete"
}

# Install ThingsBoard
install_thingsboard() {
    log_info "Installing ThingsBoard CE ${TB_VERSION}..."
    
    wget https://github.com/thingsboard/thingsboard/releases/download/v${TB_VERSION}/thingsboard-${TB_VERSION}.deb
    dpkg -i thingsboard-${TB_VERSION}.deb
    rm thingsboard-${TB_VERSION}.deb
    
    log_info "ThingsBoard installed"
}

# Configure ThingsBoard
configure_thingsboard() {
    log_info "Configuring ThingsBoard..."
    
    # Backup original config
    cp /etc/thingsboard/conf/thingsboard.conf /etc/thingsboard/conf/thingsboard.conf.backup
    
    # Update configuration
    cat >> /etc/thingsboard/conf/thingsboard.conf <<EOF

# Database Configuration
export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/${POSTGRES_DB}
export SPRING_DATASOURCE_USERNAME=thingsboard
export SPRING_DATASOURCE_PASSWORD=thingsboard

# Queue Configuration
export TB_QUEUE_TYPE=in-memory

# Server Port
export SERVER_PORT=${TB_PORT}
EOF
    
    log_info "Configuration updated"
}

# Initialize ThingsBoard
initialize_thingsboard() {
    log_info "Initializing ThingsBoard with demo data..."
    
    /usr/share/thingsboard/bin/install/install.sh --loadDemo
    
    log_info "ThingsBoard initialized"
}

# Full installation process
do_install() {
    check_root
    
    log_info "Starting ThingsBoard installation..."
    log_warn "This will install Java 11, PostgreSQL 16, and ThingsBoard CE"
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    install_java
    install_postgresql
    setup_database
    install_thingsboard
    configure_thingsboard
    initialize_thingsboard
    
    log_info "Installation complete!"
    log_info "Starting ThingsBoard service..."
    systemctl start thingsboard
    systemctl enable thingsboard
    
    sleep 5
    
    log_info "ThingsBoard is starting up. This may take a minute..."
    log_info "Access the web UI at: http://$(curl -s ifconfig.me):${TB_PORT}"
    log_info "Default credentials: sysadmin@thingsboard.org / sysadmin"
}

# Start ThingsBoard service
do_start() {
    check_root
    log_info "Starting ThingsBoard service..."
    systemctl start thingsboard
    sleep 3
    systemctl status thingsboard --no-pager
}

# Stop ThingsBoard service
do_stop() {
    check_root
    log_info "Stopping ThingsBoard service..."
    systemctl stop thingsboard
    log_info "ThingsBoard stopped"
}

# Check service status
do_status() {
    systemctl status thingsboard --no-pager
}

# View logs
do_logs() {
    log_info "Viewing ThingsBoard logs (Ctrl+C to exit)..."
    journalctl -u thingsboard -f
}

# Test telemetry endpoint
do_test() {
    read -p "Enter device access token: " TOKEN
    read -p "Enter latitude (default: 34.022): " LAT
    LAT=${LAT:-34.022}
    read -p "Enter longitude (default: -118.285): " LON
    LON=${LON:--118.285}
    
    log_info "Sending test telemetry..."
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        http://localhost:${TB_PORT}/api/v1/${TOKEN}/telemetry \
        -H 'Content-Type: application/json' \
        -d "{\"_type\":\"location\",\"lat\":${LAT},\"lon\":${LON},\"batt\":87,\"acc\":10,\"alt\":73,\"tst\":$(date +%s)}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        log_info "✓ Telemetry sent successfully!"
        log_info "  Latitude: ${LAT}"
        log_info "  Longitude: ${LON}"
    else
        log_error "✗ Failed to send telemetry (HTTP ${HTTP_CODE})"
        echo "$BODY"
    fi
}

# Show usage
show_usage() {
    cat <<EOF
ThingsBoard Location Tracking Setup Script

Usage: $0 {install|start|stop|status|logs|test}

Commands:
  install    Install ThingsBoard and all dependencies
  start      Start ThingsBoard service
  stop       Stop ThingsBoard service
  status     Check ThingsBoard service status
  logs       View ThingsBoard service logs (real-time)
  test       Test telemetry endpoint with sample data

Examples:
  sudo $0 install
  sudo $0 start
  $0 status
  $0 test

EOF
}

# Main script logic
case "$1" in
    install)
        do_install
        ;;
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    status)
        do_status
        ;;
    logs)
        do_logs
        ;;
    test)
        do_test
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

exit 0
