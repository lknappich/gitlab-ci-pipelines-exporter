#!/bin/bash

# Simple Build and Push Script for GitLab CI Pipelines Exporter
set -e

# Configuration
REGISTRY="registry.homesec.data.server.lan:5000"
IMAGE_NAME="gitlab-ci-pipelines-exporter"
TAG="${1:-latest}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "🐳 Building and pushing GitLab CI Pipelines Exporter"
echo "Registry: ${REGISTRY}"
echo "Image: ${FULL_IMAGE}"
echo

# Build the image
echo "Building image..."
docker build -t "${FULL_IMAGE}" .

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Login and push
echo "Logging into registry..."
docker login "${REGISTRY}"

echo "Pushing image..."
docker push "${FULL_IMAGE}"

if [ $? -eq 0 ]; then
    echo "✅ Push successful!"
    echo
    echo "Your image is ready: ${FULL_IMAGE}"
    echo
    echo "In your Kubernetes deployment, use:"
    echo "  image: ${FULL_IMAGE}"
    echo "  env:"
    echo "    - name: GCPE_GITLAB_TOKEN"
    echo "      value: \"your_gitlab_token_here\""
else
    echo "❌ Push failed!"
    exit 1
fi
