#!/bin/bash
# Garfenter Preview Environment - List Script
# Usage: ./preview-list.sh [product]
# Example: ./preview-list.sh       (list all)
#          ./preview-list.sh erp   (list only erp previews)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PREVIEW_REGISTRY="$PROJECT_ROOT/.preview-registry"

FILTER_PRODUCT="$1"

echo "============================================"
echo "Garfenter Preview Environments"
echo "============================================"
echo ""

# List from Docker containers (live state)
echo "Active Containers:"
echo "-------------------------------------------"

if [[ -n "$FILTER_PRODUCT" ]]; then
    CONTAINERS=$(docker ps --format '{{.Names}}|{{.Status}}|{{.CreatedAt}}' 2>/dev/null | grep "garfenter-${FILTER_PRODUCT}-preview-" || true)
else
    CONTAINERS=$(docker ps --format '{{.Names}}|{{.Status}}|{{.CreatedAt}}' 2>/dev/null | grep "preview-" || true)
fi

if [[ -z "$CONTAINERS" ]]; then
    echo "  No active preview containers"
else
    printf "%-40s %-20s %s\n" "CONTAINER" "STATUS" "URL"
    printf "%-40s %-20s %s\n" "----------------------------------------" "--------------------" "----------------------------------------"

    while IFS='|' read -r name status created; do
        # Extract product and code from container name
        # Format: garfenter-<product>-preview-<code>
        if [[ "$name" =~ garfenter-([a-z]+)-(preview-[a-z0-9]+) ]]; then
            product="${BASH_REMATCH[1]}"
            code="${BASH_REMATCH[2]}"
            url="https://${code}.${product}.garfenter.com"
            short_status=$(echo "$status" | cut -d' ' -f1-2)
            printf "%-40s %-20s %s\n" "$name" "$short_status" "$url"
        fi
    done <<< "$CONTAINERS"
fi

echo ""
echo "Registry Entries:"
echo "-------------------------------------------"

if [[ ! -d "$PREVIEW_REGISTRY" ]] || [[ -z "$(ls -A "$PREVIEW_REGISTRY" 2>/dev/null)" ]]; then
    echo "  No registry entries found"
else
    printf "%-15s %-20s %-30s %s\n" "PRODUCT" "CODE" "DOMAIN" "CREATED"
    printf "%-15s %-20s %-30s %s\n" "---------------" "--------------------" "------------------------------" "------------------------"

    for file in "$PREVIEW_REGISTRY"/*.json; do
        if [[ -f "$file" ]]; then
            product=$(jq -r '.product' "$file" 2>/dev/null)
            code=$(jq -r '.code' "$file" 2>/dev/null)
            domain=$(jq -r '.domain' "$file" 2>/dev/null)
            created=$(jq -r '.created_at' "$file" 2>/dev/null)

            if [[ -z "$FILTER_PRODUCT" ]] || [[ "$product" == "$FILTER_PRODUCT" ]]; then
                printf "%-15s %-20s %-30s %s\n" "$product" "$code" "$domain" "$created"
            fi
        fi
    done
fi

echo ""
echo "============================================"
echo "Commands:"
echo "  Create:  ./preview-create.sh <product> [code]"
echo "  Destroy: ./preview-destroy.sh <product> <code>"
echo "============================================"
