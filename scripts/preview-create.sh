#!/bin/bash
# Garfenter Preview Environment - Create Script
# Usage: ./preview-create.sh <product> [code]
# Example: ./preview-create.sh erp abc123
#          ./preview-create.sh tienda  (auto-generates code)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PRODUCTS_ROOT="$(dirname "$PROJECT_ROOT")"

# Product configuration (product -> directory, port)
declare -A PRODUCT_CONFIG=(
    ["erp"]="erp/odoo:8069"
    ["tienda"]="ecommerce/saleor:8000"
    ["mercado"]="marketplace/spurtcommerce:8000"
    ["clientes"]="crm/twenty:3000"
    ["contable"]="accounting/bigcapital:3000"
    ["inmuebles"]="real-estate/condo:3000"
    ["pos"]="pos/ospos:80"
    ["salud"]="healthcare/hmis:80"
    ["banco"]="banking/fineract:8443"
    ["campo"]="agriculture/farmos:80"
    ["educacion"]="education/canvas-lms:3000"
)

# Validate product
PRODUCT="$1"
PREVIEW_CODE="${2:-preview-$(head -c 6 /dev/urandom | xxd -p)}"

if [[ -z "$PRODUCT" ]]; then
    echo "Usage: $0 <product> [code]"
    echo ""
    echo "Available products:"
    for p in "${!PRODUCT_CONFIG[@]}"; do
        echo "  - $p"
    done | sort
    exit 1
fi

if [[ -z "${PRODUCT_CONFIG[$PRODUCT]}" ]]; then
    echo "Error: Unknown product '$PRODUCT'"
    echo ""
    echo "Available products:"
    for p in "${!PRODUCT_CONFIG[@]}"; do
        echo "  - $p"
    done | sort
    exit 1
fi

# Parse config
IFS=':' read -r PRODUCT_DIR PORT <<< "${PRODUCT_CONFIG[$PRODUCT]}"
PRODUCT_PATH="$PRODUCTS_ROOT/$PRODUCT_DIR"

if [[ ! -d "$PRODUCT_PATH" ]]; then
    echo "Error: Product directory not found: $PRODUCT_PATH"
    exit 1
fi

CONTAINER_NAME="garfenter-${PRODUCT}-${PREVIEW_CODE}"
NETWORK_NAME="garfenter-network"
DOMAIN="${PREVIEW_CODE}.${PRODUCT}.garfenter.com"

echo "============================================"
echo "Creating Preview Environment"
echo "============================================"
echo "Product:   $PRODUCT"
echo "Code:      $PREVIEW_CODE"
echo "Container: $CONTAINER_NAME"
echo "URL:       https://$DOMAIN"
echo "============================================"
echo ""

# Ensure network exists
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Creating network: $NETWORK_NAME"
    docker network create "$NETWORK_NAME"
fi

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Warning: Container $CONTAINER_NAME already exists"
    echo "Removing existing container..."
    docker rm -f "$CONTAINER_NAME" >/dev/null
fi

# Change to product directory and start preview container
cd "$PRODUCT_PATH"

# Check if docker-compose.garfenter.yml exists
if [[ ! -f "docker-compose.garfenter.yml" ]]; then
    echo "Error: docker-compose.garfenter.yml not found in $PRODUCT_PATH"
    exit 1
fi

# Create preview-specific compose file
PREVIEW_COMPOSE_FILE="/tmp/docker-compose.preview-${PRODUCT}-${PREVIEW_CODE}.yml"

echo "Generating preview compose file..."
cat > "$PREVIEW_COMPOSE_FILE" << EOF
# Auto-generated preview environment for $PRODUCT
# Code: $PREVIEW_CODE
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

version: '3.8'

services:
  $CONTAINER_NAME:
    extends:
      file: docker-compose.garfenter.yml
      service: garfenter-${PRODUCT}
    container_name: $CONTAINER_NAME
    networks:
      - $NETWORK_NAME
    labels:
      - "garfenter.preview=true"
      - "garfenter.preview.code=$PREVIEW_CODE"
      - "garfenter.preview.product=$PRODUCT"
      - "garfenter.preview.domain=$DOMAIN"
      - "garfenter.preview.created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

networks:
  $NETWORK_NAME:
    external: true
EOF

echo "Starting preview container..."
docker compose -f "$PREVIEW_COMPOSE_FILE" up -d

echo ""
echo "============================================"
echo "Preview Environment Created!"
echo "============================================"
echo "URL:       https://$DOMAIN"
echo "Container: $CONTAINER_NAME"
echo ""
echo "To destroy: ./preview-destroy.sh $PRODUCT $PREVIEW_CODE"
echo "============================================"

# Save preview info to registry
PREVIEW_REGISTRY="$PROJECT_ROOT/.preview-registry"
mkdir -p "$PREVIEW_REGISTRY"
cat > "$PREVIEW_REGISTRY/${PRODUCT}-${PREVIEW_CODE}.json" << EOF
{
  "product": "$PRODUCT",
  "code": "$PREVIEW_CODE",
  "container": "$CONTAINER_NAME",
  "domain": "$DOMAIN",
  "port": "$PORT",
  "compose_file": "$PREVIEW_COMPOSE_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo ""
echo "Preview registered at: $PREVIEW_REGISTRY/${PRODUCT}-${PREVIEW_CODE}.json"
