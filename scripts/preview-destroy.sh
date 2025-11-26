#!/bin/bash
# Garfenter Preview Environment - Destroy Script
# Usage: ./preview-destroy.sh <product> <code>
# Example: ./preview-destroy.sh erp preview-abc123

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PREVIEW_REGISTRY="$PROJECT_ROOT/.preview-registry"

PRODUCT="$1"
PREVIEW_CODE="$2"

if [[ -z "$PRODUCT" ]] || [[ -z "$PREVIEW_CODE" ]]; then
    echo "Usage: $0 <product> <code>"
    echo "Example: $0 erp preview-abc123"
    echo ""
    echo "Use './preview-list.sh' to see active preview environments"
    exit 1
fi

CONTAINER_NAME="garfenter-${PRODUCT}-${PREVIEW_CODE}"
REGISTRY_FILE="$PREVIEW_REGISTRY/${PRODUCT}-${PREVIEW_CODE}.json"

echo "============================================"
echo "Destroying Preview Environment"
echo "============================================"
echo "Product:   $PRODUCT"
echo "Code:      $PREVIEW_CODE"
echo "Container: $CONTAINER_NAME"
echo "============================================"
echo ""

# Check if container exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping container: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true

    echo "Removing container: $CONTAINER_NAME"
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

    echo "Container destroyed successfully"
else
    echo "Warning: Container $CONTAINER_NAME not found"
fi

# Clean up compose file
PREVIEW_COMPOSE_FILE="/tmp/docker-compose.preview-${PRODUCT}-${PREVIEW_CODE}.yml"
if [[ -f "$PREVIEW_COMPOSE_FILE" ]]; then
    echo "Removing compose file..."
    rm -f "$PREVIEW_COMPOSE_FILE"
fi

# Remove from registry
if [[ -f "$REGISTRY_FILE" ]]; then
    echo "Removing from registry..."
    rm -f "$REGISTRY_FILE"
fi

echo ""
echo "============================================"
echo "Preview Environment Destroyed!"
echo "============================================"
