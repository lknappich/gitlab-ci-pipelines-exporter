#!/bin/bash

# Build and Push Script for GitLab CI Pipelines Exporter
# Registry: http://registry.homesec.data.server.lan

set -e

# Configuration
REGISTRY="registry.homesec.data.server.lan"
IMAGE_NAME="gitlab-ci-pipelines-exporter"
TAG="${1:-latest}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🐳 Building and Pushing GitLab CI Pipelines Exporter${NC}"
echo "=================================================="
echo

# Step 1: Login to private registry
echo -e "${YELLOW}Step 1: Logging into private registry${NC}"
echo "Registry: http://${REGISTRY}"
echo
read -p "Enter your registry username: " username
read -s -p "Enter your registry password: " password
echo

# Login to Docker registry
echo "$password" | docker login "http://${REGISTRY}" --username "$username" --password-stdin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully logged into registry${NC}"
else
    echo -e "${RED}✗ Failed to login to registry${NC}"
    exit 1
fi
echo

# Step 2: Build the Docker image
echo -e "${YELLOW}Step 2: Building Docker image${NC}"
echo "Building: ${FULL_IMAGE}"
echo

docker build -t "${FULL_IMAGE}" .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully built image: ${FULL_IMAGE}${NC}"
else
    echo -e "${RED}✗ Failed to build image${NC}"
    exit 1
fi
echo

# Step 3: Push to registry
echo -e "${YELLOW}Step 3: Pushing to registry${NC}"
echo "Pushing: ${FULL_IMAGE}"
echo

docker push "${FULL_IMAGE}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully pushed image: ${FULL_IMAGE}${NC}"
else
    echo -e "${RED}✗ Failed to push image${NC}"
    exit 1
fi
echo

# Step 4: Show deployment information
echo -e "${BLUE}📋 Deployment Information${NC}"
echo "========================="
echo "Registry: http://${REGISTRY}"
echo "Image: ${FULL_IMAGE}"
echo "Tag: ${TAG}"
echo
echo "Next steps:"
echo "1. Update the Kubernetes deployment YAML with this image"
echo "2. Apply the Kubernetes manifests: kubectl apply -f k8s/"
echo "3. Check pod status: kubectl get pods -l app=gitlab-ci-pipelines-exporter"
echo

# Step 5: Clean up local image (optional)
read -p "Remove local image to save space? (y/N): " cleanup
if [[ "$cleanup" =~ ^[Yy]$ ]]; then
    docker rmi "${FULL_IMAGE}"
    echo -e "${GREEN}✓ Local image removed${NC}"
fi

echo -e "${GREEN}🎉 Build and push completed successfully!${NC}"
