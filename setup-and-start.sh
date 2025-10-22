#!/bin/bash

# GitLab CI Pipelines Exporter Setup and Start Script
# This script will help you configure and start the exporter

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🦊 GitLab CI Pipelines Exporter Setup${NC}"
echo "========================================="
echo

# Step 1: Check GitLab Token
if [ -z "$GCPE_GITLAB_TOKEN" ]; then
    echo -e "${YELLOW}Step 1: GitLab Token Configuration${NC}"
    echo "You need a GitLab personal access token with 'api' and 'read_repository' permissions."
    echo
    echo "To create a token:"
    echo "1. Go to https://gitlab.capturecore.de/-/profile/personal_access_tokens"
    echo "2. Create a new token with 'api' and 'read_repository' scopes"
    echo "3. Copy the token"
    echo
    read -p "Enter your GitLab token: " token
    if [ -z "$token" ]; then
        echo -e "${RED}Token is required to continue${NC}"
        exit 1
    fi
    export GCPE_GITLAB_TOKEN="$token"
    echo -e "${GREEN}✓ Token set${NC}"
    echo
fi

# Step 2: Configure Projects
echo -e "${YELLOW}Step 2: Project Configuration${NC}"
echo "You need to specify which projects to monitor."
echo
echo "Choose an option:"
echo "1. Monitor specific projects (recommended for getting started)"
echo "2. Monitor all projects in a group (requires group name)"
echo
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo
        echo "Please provide your project names in the format: group-name/project-name"
        echo "Example: mycompany/backend-api"
        echo
        projects=()
        while true; do
            read -p "Enter project name (or press Enter to finish): " project
            if [ -z "$project" ]; then
                break
            fi
            projects+=("$project")
            echo -e "${GREEN}✓ Added: $project${NC}"
        done

        if [ ${#projects[@]} -eq 0 ]; then
            echo -e "${RED}At least one project is required${NC}"
            exit 1
        fi

        # Update configuration with specific projects
        {
            head -n -8 gitlab-ci-pipelines-exporter.yml
            echo "projects:"
            for project in "${projects[@]}"; do
                echo "  - name: \"$project\""
            done
            echo
            echo "# Option 2: Monitor all projects in a group (Alternative)"
            echo "# wildcards:"
            echo "#   - owner:"
            echo "#       name: \"your-group-name\""
            echo "#       kind: group"
            echo "#       include_subgroups: true"
            echo "#     archived: false"
        } > gitlab-ci-pipelines-exporter.yml.tmp
        mv gitlab-ci-pipelines-exporter.yml.tmp gitlab-ci-pipelines-exporter.yml
        ;;
    2)
        echo
        read -p "Enter your GitLab group name: " group_name
        if [ -z "$group_name" ]; then
            echo -e "${RED}Group name is required${NC}"
            exit 1
        fi

        # Update configuration with wildcard
        {
            head -n -8 gitlab-ci-pipelines-exporter.yml
            echo "# Option 1: Monitor specific projects"
            echo "# projects:"
            echo "#   - name: \"your-group/your-project\""
            echo
            echo "# Option 2: Monitor all projects in a group"
            echo "wildcards:"
            echo "  - owner:"
            echo "      name: \"$group_name\""
            echo "      kind: group"
            echo "      include_subgroups: true"
            echo "    archived: false"
        } > gitlab-ci-pipelines-exporter.yml.tmp
        mv gitlab-ci-pipelines-exporter.yml.tmp gitlab-ci-pipelines-exporter.yml
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ Configuration updated${NC}"
echo

# Step 3: Test GitLab connectivity
echo -e "${YELLOW}Step 3: Testing GitLab connectivity${NC}"
echo "Testing connection to https://gitlab.capturecore.de..."

# Test GitLab API connection with better error handling
response=$(curl -s -w "%{http_code}" -H "PRIVATE-TOKEN: $GCPE_GITLAB_TOKEN" "https://gitlab.capturecore.de/api/v4/user" -o /dev/null)

if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ GitLab connection successful${NC}"
else
    echo -e "${RED}✗ GitLab connection failed (HTTP status: $response)${NC}"
    echo "Please check your token and GitLab URL"
    echo "Trying to get more information..."
    curl -s -H "PRIVATE-TOKEN: $GCPE_GITLAB_TOKEN" "https://gitlab.capturecore.de/api/v4/user" | head -c 200
    echo
    exit 1
fi
echo

# Step 4: Start the exporter
echo -e "${YELLOW}Step 4: Starting GitLab CI Pipelines Exporter${NC}"
echo "Starting with Docker Compose..."

# Stop any existing container
sudo docker compose down 2>/dev/null || true

# Start the exporter
sudo GCPE_GITLAB_TOKEN="$GCPE_GITLAB_TOKEN" docker compose up -d

echo
echo -e "${GREEN}✓ Exporter started successfully!${NC}"
echo
echo -e "${BLUE}Useful Information:${NC}"
echo "  - Metrics endpoint: http://localhost:8080/metrics"
echo "  - Health check: http://localhost:8080/health"
echo "  - View logs: sudo docker logs gitlab-ci-pipelines-exporter -f"
echo "  - Stop exporter: sudo docker compose down"
echo
echo -e "${BLUE}Branch Monitoring:${NC}"
echo "  The exporter is configured to monitor these branches:"
echo "  - main, master, qa, development, dev, staging"
echo "  - feature/* and hotfix/* branches"
echo "  - merge requests"
echo
echo "The exporter will start collecting metrics shortly. Check the logs to monitor progress."
echo "It may take a few minutes to discover all projects and branches."
