#!/bin/bash
# Garfenter Preview Environment - Cleanup Script
# Destroys all preview environments or those older than specified hours
# Usage: ./preview-cleanup.sh [--older-than <hours>] [--product <product>] [--force]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PREVIEW_REGISTRY="$PROJECT_ROOT/.preview-registry"

OLDER_THAN_HOURS=""
FILTER_PRODUCT=""
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --older-than)
            OLDER_THAN_HOURS="$2"
            shift 2
            ;;
        --product)
            FILTER_PRODUCT="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --older-than <hours>  Only destroy environments older than N hours"
            echo "  --product <product>   Only destroy environments for specific product"
            echo "  --force               Skip confirmation prompt"
            echo ""
            echo "Examples:"
            echo "  $0                          # Destroy all previews (with confirmation)"
            echo "  $0 --force                  # Destroy all previews (no confirmation)"
            echo "  $0 --older-than 24          # Destroy previews older than 24 hours"
            echo "  $0 --product erp --force    # Destroy all erp previews"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "============================================"
echo "Garfenter Preview Environment Cleanup"
echo "============================================"

# Find preview containers
CONTAINERS=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep "preview-" || true)

if [[ -z "$CONTAINERS" ]]; then
    echo "No preview containers found."
    exit 0
fi

# Filter by product if specified
if [[ -n "$FILTER_PRODUCT" ]]; then
    CONTAINERS=$(echo "$CONTAINERS" | grep "garfenter-${FILTER_PRODUCT}-preview-" || true)
fi

if [[ -z "$CONTAINERS" ]]; then
    echo "No matching preview containers found."
    exit 0
fi

# Count containers
COUNT=$(echo "$CONTAINERS" | wc -l | tr -d ' ')
echo ""
echo "Found $COUNT preview container(s) to destroy:"
echo "$CONTAINERS" | while read -r container; do
    echo "  - $container"
done

# Confirmation
if [[ "$FORCE" != true ]]; then
    echo ""
    read -p "Are you sure you want to destroy these containers? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo ""
echo "Destroying preview environments..."
echo ""

DESTROYED=0
FAILED=0

echo "$CONTAINERS" | while read -r container; do
    if [[ -n "$container" ]]; then
        echo "Destroying: $container"

        # Extract product and code
        if [[ "$container" =~ garfenter-([a-z]+)-(preview-[a-z0-9]+) ]]; then
            product="${BASH_REMATCH[1]}"
            code="${BASH_REMATCH[2]}"

            # Stop and remove container
            docker stop "$container" >/dev/null 2>&1 || true
            docker rm "$container" >/dev/null 2>&1 || true

            # Clean up compose file
            rm -f "/tmp/docker-compose.preview-${product}-${code}.yml" 2>/dev/null || true

            # Remove from registry
            rm -f "$PREVIEW_REGISTRY/${product}-${code}.json" 2>/dev/null || true

            echo "  -> Destroyed"
        else
            echo "  -> Failed to parse container name"
        fi
    fi
done

echo ""
echo "============================================"
echo "Cleanup complete!"
echo "============================================"
