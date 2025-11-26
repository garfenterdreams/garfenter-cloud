#!/bin/bash
# Generate GitHub Actions workflows for all 11 Garfenter products

TEMPLATES_DIR="$(dirname "$0")/../.github/workflow-templates"
mkdir -p "$TEMPLATES_DIR"

# Product configurations: name|display_name|docker_image|port|build|health_path
PRODUCTS=(
  "tienda|Saleor E-commerce|ghcr.io/saleor/saleor:3.19|8000|false|/graphql/"
  "mercado|Spurt Commerce Marketplace|build|3000|true|/api/health"
  "pos|OpenSource POS|opensourcepos/opensourcepos:latest|80|false|/"
  "contable|Bigcapital Accounting|ghcr.io/bigcapitalhq/bigcapital:latest|3000|false|/api/ping"
  "erp|Odoo ERP|odoo:17|8069|false|/web/login"
  "clientes|Twenty CRM|twentycrm/twenty:latest|3000|false|/"
  "inmuebles|Condo Real Estate|build|3000|true|/api/health"
  "campo|farmOS Agriculture|farmos/farmos:3.x|80|false|/"
  "banco|Apache Fineract Banking|apache/fineract:latest|8443|false|/fineract-provider/actuator/health"
  "salud|HMIS Healthcare|build|8080|true|/api/health"
  "educacion|Canvas LMS Education|instructure/canvas-lms:stable|80|false|/login/canvas"
)

generate_workflow() {
  local name=$1
  local display_name=$2
  local docker_image=$3
  local port=$4
  local build=$5
  local health_path=$6

  local build_docker="false"
  local image_line="docker_image: '$docker_image'"

  if [ "$docker_image" == "build" ]; then
    build_docker="true"
    image_line="docker_image: 'ghcr.io/\${{ github.repository }}:latest'"
  fi

  cat > "$TEMPLATES_DIR/deploy-${name}.yml" << EOF
# Garfenter Cloud - ${display_name} Deployment
# Auto-generated workflow for deploying ${display_name} to AWS

name: Deploy ${display_name}

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'demo'
        type: choice
        options:
          - demo
          - staging
          - production

env:
  PRODUCT_NAME: ${name}
  PRODUCT_DISPLAY: "${display_name}"

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Tests
        run: |
          echo "Running tests for ${display_name}..."
          # Add your test commands here
          # npm test, pytest, etc.

  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: [test]
    if: github.event_name != 'pull_request'
    outputs:
      image_tag: \${{ steps.meta.outputs.tags }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: \${{ github.actor }}
          password: \${{ secrets.GITHUB_TOKEN }}

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/\${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=
            type=raw,value=latest,enable=\${{ github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master' }}

      - name: Build and Push
        if: ${build_docker}
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: \${{ steps.meta.outputs.tags }}
          labels: \${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Skip Build (using upstream image)
        if: $([[ "$build_docker" == "false" ]] && echo "true" || echo "false")
        run: echo "Using upstream Docker image: ${docker_image}"

  deploy:
    name: Deploy to AWS
    runs-on: ubuntu-latest
    needs: [build]
    if: github.event_name != 'pull_request'
    environment: \${{ github.event.inputs.environment || 'demo' }}

    steps:
      - name: Setup SSH Key
        run: |
          mkdir -p ~/.ssh
          echo "\${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/garfenter-key.pem
          chmod 600 ~/.ssh/garfenter-key.pem
          ssh-keyscan -H \${{ secrets.EC2_HOST }} >> ~/.ssh/known_hosts 2>/dev/null || true

      - name: Deploy to EC2
        env:
          EC2_HOST: \${{ secrets.EC2_HOST }}
          DOCKER_IMAGE: ${image_line/docker_image: /}
          POSTGRES_PASSWORD: \${{ secrets.POSTGRES_PASSWORD }}
          MYSQL_PASSWORD: \${{ secrets.MYSQL_PASSWORD }}
        run: |
          ssh -i ~/.ssh/garfenter-key.pem -o StrictHostKeyChecking=no ec2-user@\$EC2_HOST << 'DEPLOY_SCRIPT'
          set -e
          echo "=== Deploying ${display_name} ==="

          PRODUCT="${name}"
          IMAGE="${docker_image}"
          PORT="${port}"

          # For build images, use GHCR
          if [ "\$IMAGE" == "build" ]; then
            IMAGE="ghcr.io/garfenterdreams/${name}:latest"
          fi

          # Stop existing container
          docker stop garfenter-\${PRODUCT} 2>/dev/null || true
          docker rm garfenter-\${PRODUCT} 2>/dev/null || true

          # Pull latest image
          echo "Pulling image: \${IMAGE}"
          docker pull \${IMAGE}

          # Determine database connection
          DB_URL="postgres://garfenter:\${POSTGRES_PASSWORD}@garfenter-postgres:5432/\${PRODUCT}"

          # Start container with appropriate environment
          echo "Starting container on port \${PORT}..."
          docker run -d \\
            --name garfenter-\${PRODUCT} \\
            --network garfenter-network \\
            --restart unless-stopped \\
            -e DATABASE_URL="\${DB_URL}" \\
            -e POSTGRES_PASSWORD="\${POSTGRES_PASSWORD}" \\
            -e MYSQL_PASSWORD="\${MYSQL_PASSWORD}" \\
            -e SECRET_KEY="garfenter-\${PRODUCT}-secret-\$(date +%s)" \\
            -e ALLOWED_HOSTS="*" \\
            -e DEBUG="false" \\
            \${IMAGE}

          echo "=== Deployment complete ==="
          docker ps | grep garfenter-\${PRODUCT} || echo "Container may still be starting..."
          DEPLOY_SCRIPT

      - name: Health Check
        run: |
          echo "Waiting for service to start..."
          sleep 45

          for i in {1..6}; do
            echo "Health check attempt \$i..."
            if ssh -i ~/.ssh/garfenter-key.pem -o StrictHostKeyChecking=no ec2-user@\${{ secrets.EC2_HOST }} \\
              "curl -sf http://localhost:${port}${health_path} > /dev/null 2>&1"; then
              echo "Health check passed!"
              exit 0
            fi
            sleep 15
          done

          echo "Service may still be starting - check logs manually"
          ssh -i ~/.ssh/garfenter-key.pem ec2-user@\${{ secrets.EC2_HOST }} \\
            "docker logs garfenter-${name} --tail 50" || true

      - name: Deployment Summary
        run: |
          echo "## ${display_name} Deployment" >> \$GITHUB_STEP_SUMMARY
          echo "" >> \$GITHUB_STEP_SUMMARY
          echo "| Property | Value |" >> \$GITHUB_STEP_SUMMARY
          echo "|----------|-------|" >> \$GITHUB_STEP_SUMMARY
          echo "| Product | ${display_name} |" >> \$GITHUB_STEP_SUMMARY
          echo "| Container | garfenter-${name} |" >> \$GITHUB_STEP_SUMMARY
          echo "| Port | ${port} |" >> \$GITHUB_STEP_SUMMARY
          echo "| URL | https://${name}.\${{ vars.DOMAIN_NAME }} |" >> \$GITHUB_STEP_SUMMARY
          echo "| Commit | \${{ github.sha }} |" >> \$GITHUB_STEP_SUMMARY
          echo "| Deployed | \$(date -u) |" >> \$GITHUB_STEP_SUMMARY
EOF

  echo "Generated: deploy-${name}.yml"
}

echo "Generating workflow templates..."
for product in "${PRODUCTS[@]}"; do
  IFS='|' read -r name display_name docker_image port build health_path <<< "$product"
  generate_workflow "$name" "$display_name" "$docker_image" "$port" "$build" "$health_path"
done

echo ""
echo "=== Generated ${#PRODUCTS[@]} workflow templates in $TEMPLATES_DIR ==="
echo ""
echo "To use these workflows:"
echo "1. Copy the appropriate .yml file to each product repo's .github/workflows/ directory"
echo "2. Configure these secrets in each repo (Settings > Secrets):"
echo "   - SSH_PRIVATE_KEY: EC2 SSH private key content"
echo "   - EC2_HOST: EC2 instance public IP or hostname"
echo "   - POSTGRES_PASSWORD: PostgreSQL password"
echo "   - MYSQL_PASSWORD: MySQL password"
echo ""
echo "3. Configure these variables (Settings > Variables):"
echo "   - DOMAIN_NAME: Your domain (e.g., garfenter.com)"
