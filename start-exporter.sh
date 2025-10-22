#!/bin/bash

# GitLab CI Pipelines Exporter Startup Script
# Make sure to set your GitLab token before running

set -e

# Configuration
CONFIG_FILE="./gitlab-ci-pipelines-exporter.yml"
DEFAULT_PORT="8080"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🦊 GitLab CI Pipelines Exporter Startup${NC}"
echo "=================================="

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Check if GitLab token is set
if [ -z "$GCPE_GITLAB_TOKEN" ]; then
    echo -e "${YELLOW}Warning: GCPE_GITLAB_TOKEN environment variable not set${NC}"
    echo "Please set your GitLab token:"
    echo "  export GCPE_GITLAB_TOKEN=your_gitlab_token_here"
    echo ""
    read -p "Enter your GitLab token (or press Ctrl+C to exit): " token
    if [ ! -z "$token" ]; then
        export GCPE_GITLAB_TOKEN="$token"
    else
        echo -e "${RED}Token is required to continue${NC}"
        exit 1
    fi
fi

# Validate configuration
echo "Validating configuration..."

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo ""
    echo "To install Docker on Ubuntu/Debian:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    echo "  sudo usermod -aG docker \$USER"
    echo "  # Log out and back in, or run: newgrp docker"
    echo ""
    echo "To install Docker on other systems, visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is available (modern docker compose command)
if ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker Compose is not available${NC}"
    echo "Make sure you have Docker Compose plugin installed."
    echo "Run: sudo apt-get update && sudo apt-get install docker-compose-plugin"
    exit 1
fi

if command -v gitlab-ci-pipelines-exporter >/dev/null 2>&1; then
    gitlab-ci-pipelines-exporter validate --config "$CONFIG_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Configuration validation failed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Configuration is valid${NC}"
else
    echo -e "${YELLOW}Warning: gitlab-ci-pipelines-exporter binary not found in PATH${NC}"
    echo "Using Docker instead..."
fi

echo ""
echo "Configuration summary:"
echo "  - Monitoring branches: main, master, qa, development, staging, feature/*, hotfix/*"
echo "  - Merge requests: enabled"
echo "  - Job-level metrics: enabled"
echo "  - Environment monitoring: enabled"
echo "  - Metrics endpoint: http://localhost:${DEFAULT_PORT}/metrics"
echo ""

# Show run options
echo "Run options:"
echo ""
echo "1. Using binary (if installed):"
echo "   gitlab-ci-pipelines-exporter run --config $CONFIG_FILE"
echo ""
echo "2. Using Docker:"
echo "   docker run -d \\"
echo "     --name gitlab-ci-pipelines-exporter \\"
echo "     -p ${DEFAULT_PORT}:${DEFAULT_PORT} \\"
echo "     -v \$(pwd)/${CONFIG_FILE}:/etc/config.yml \\"
echo "     -e GCPE_GITLAB_TOKEN=\$GCPE_GITLAB_TOKEN \\"
echo "     mvisonneau/gitlab-ci-pipelines-exporter:latest \\"
echo "     run --config /etc/config.yml"
echo ""
echo "3. Using Docker Compose (recommended):"

# Create compose.yml if it doesn't exist
if [ ! -f "compose.yml" ]; then
    echo "   Creating compose.yml..."
    cat > compose.yml << 'EOF'
version: '3.8'

services:
  gitlab-ci-pipelines-exporter:
    image: mvisonneau/gitlab-ci-pipelines-exporter:latest
    container_name: gitlab-ci-pipelines-exporter
    ports:
      - "8080:8080"
    volumes:
      - ./gitlab-ci-pipelines-exporter.yml:/etc/config.yml:ro
    environment:
      - GCPE_GITLAB_TOKEN=${GCPE_GITLAB_TOKEN}
    command: run --config /etc/config.yml
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Optional: Add Prometheus for metrics storage
  # prometheus:
  #   image: prom/prometheus:latest
  #   container_name: prometheus
  #   ports:
  #     - "9090:9090"
  #   volumes:
  #     - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
  #   command:
  #     - '--config.file=/etc/prometheus/prometheus.yml'
  #     - '--storage.tsdb.path=/prometheus'
  #     - '--web.console.libraries=/etc/prometheus/console_libraries'
  #     - '--web.console.templates=/etc/prometheus/consoles'
  #     - '--web.enable-lifecycle'
EOF
    echo -e "   ${GREEN}✓ Created compose.yml${NC}"
fi

echo "   docker compose up -d"
echo ""

# Ask if user wants to start immediately
read -p "Start the exporter now with Docker Compose? (y/N): " start_now
if [[ "$start_now" =~ ^[Yy]$ ]]; then
    echo "Starting GitLab CI Pipelines Exporter..."
    docker compose up -d
    echo ""
    echo -e "${GREEN}✓ Exporter started successfully!${NC}"
    echo ""
    echo "Useful commands:"
    echo "  - View logs: docker compose logs -f gitlab-ci-pipelines-exporter"
    echo "  - Check metrics: curl http://localhost:${DEFAULT_PORT}/metrics"
    echo "  - Check health: curl http://localhost:${DEFAULT_PORT}/health"
    echo "  - Stop: docker compose down"
    echo ""
    echo "The exporter will now monitor pipelines from all configured branches including qa and development!"
fi
