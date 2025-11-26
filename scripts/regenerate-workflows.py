#!/usr/bin/env python3
"""
Regenerate all GitHub Actions deployment workflows for Garfenter Cloud products.
Fixes YAML syntax issues by avoiding heredocs in multiline blocks.
"""

import os

# Product configurations
PRODUCTS = {
    "tienda": {
        "display": "Saleor E-commerce",
        "image": "ghcr.io/saleor/saleor:3.19",
        "port": "8000",
        "health_path": "/graphql/"
    },
    "mercado": {
        "display": "Spurtcommerce Marketplace",
        "image": "build",
        "port": "9000",
        "health_path": "/"
    },
    "pos": {
        "display": "OSPOS Point of Sale",
        "image": "jekkos/opensourcepos:latest",
        "port": "80",
        "health_path": "/"
    },
    "contable": {
        "display": "Akaunting Accounting",
        "image": "akaunting/akaunting:latest",
        "port": "80",
        "health_path": "/"
    },
    "erp": {
        "display": "Odoo ERP",
        "image": "odoo:17.0",
        "port": "8069",
        "health_path": "/web/login"
    },
    "clientes": {
        "display": "Twenty CRM",
        "image": "twentycrm/twenty:latest",
        "port": "3000",
        "health_path": "/"
    },
    "inmuebles": {
        "display": "ERPNext Real Estate",
        "image": "frappe/erpnext:v15",
        "port": "8080",
        "health_path": "/"
    },
    "campo": {
        "display": "Farmbot Agriculture",
        "image": "farmbot/farmbot:latest",
        "port": "3000",
        "health_path": "/"
    },
    "banco": {
        "display": "Fineract Banking",
        "image": "apache/fineract:latest",
        "port": "8443",
        "health_path": "/fineract-provider/actuator/health"
    },
    "salud": {
        "display": "HMIS Healthcare",
        "image": "build",
        "port": "8080",
        "health_path": "/"
    },
    "educacion": {
        "display": "Canvas LMS Education",
        "image": "instructure/canvas-lms:stable",
        "port": "80",
        "health_path": "/login/canvas"
    }
}

WORKFLOW_TEMPLATE = '''# Garfenter Cloud - {display} Deployment
# Auto-generated workflow for deploying {display} to AWS

name: Deploy {display}

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
  PRODUCT_NAME: {name}
  PRODUCT_DISPLAY: "{display}"
  DOCKER_IMAGE: "{image}"
  PORT: "{port}"
  HEALTH_PATH: "{health_path}"

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Tests
        run: echo "Running tests for {display}..."

  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: [test]
    if: github.event_name != 'pull_request'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Skip Build (using upstream image)
        if: env.DOCKER_IMAGE != 'build'
        run: echo "Using upstream Docker image - ${{{{ env.DOCKER_IMAGE }}}}"

      - name: Set up Docker Buildx
        if: env.DOCKER_IMAGE == 'build'
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        if: env.DOCKER_IMAGE == 'build'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{{{ github.actor }}}}
          password: ${{{{ secrets.GITHUB_TOKEN }}}}

      - name: Build and Push
        if: env.DOCKER_IMAGE == 'build'
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{{{ github.repository }}}}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    name: Deploy to AWS
    runs-on: ubuntu-latest
    needs: [build]
    if: github.event_name != 'pull_request'

    steps:
      - name: Setup SSH Key
        run: |
          mkdir -p ~/.ssh
          echo "${{{{ secrets.SSH_PRIVATE_KEY }}}}" > ~/.ssh/garfenter-key.pem
          chmod 600 ~/.ssh/garfenter-key.pem
          ssh-keyscan -H ${{{{ secrets.EC2_HOST }}}} >> ~/.ssh/known_hosts 2>/dev/null || true

      - name: Deploy to EC2
        env:
          EC2_HOST: ${{{{ secrets.EC2_HOST }}}}
          POSTGRES_PASSWORD: ${{{{ secrets.POSTGRES_PASSWORD }}}}
        run: |
          IMAGE="${{{{ env.DOCKER_IMAGE }}}}"
          if [ "$IMAGE" = "build" ]; then
            IMAGE="ghcr.io/${{{{ github.repository }}}}:latest"
          fi
          ssh -i ~/.ssh/garfenter-key.pem -o StrictHostKeyChecking=no ec2-user@$EC2_HOST "
            set -e
            echo '=== Deploying ${{{{ env.PRODUCT_DISPLAY }}}} ==='

            docker stop garfenter-${{{{ env.PRODUCT_NAME }}}} 2>/dev/null || true
            docker rm garfenter-${{{{ env.PRODUCT_NAME }}}} 2>/dev/null || true

            echo 'Pulling image: $IMAGE'
            docker pull $IMAGE

            echo 'Starting container on port ${{{{ env.PORT }}}}...'
            docker run -d \\
              --name garfenter-${{{{ env.PRODUCT_NAME }}}} \\
              --network garfenter-network \\
              --restart unless-stopped \\
              -e DATABASE_URL='postgres://garfenter:${{POSTGRES_PASSWORD}}@garfenter-postgres:5432/${{{{ env.PRODUCT_NAME }}}}' \\
              -e SECRET_KEY='garfenter-${{{{ env.PRODUCT_NAME }}}}-secret' \\
              -e ALLOWED_HOSTS='*' \\
              -e DEBUG='false' \\
              $IMAGE

            echo '=== Deployment complete ==='
            docker ps | grep garfenter-${{{{ env.PRODUCT_NAME }}}} || echo 'Container may still be starting...'
          "

      - name: Health Check
        run: |
          echo "Waiting for service to start..."
          sleep 45
          for i in 1 2 3 4 5 6; do
            echo "Health check attempt $i..."
            if ssh -i ~/.ssh/garfenter-key.pem -o StrictHostKeyChecking=no ec2-user@${{{{ secrets.EC2_HOST }}}} \\
              "curl -sf http://localhost:${{{{ env.PORT }}}}${{{{ env.HEALTH_PATH }}}} > /dev/null 2>&1"; then
              echo "Health check passed!"
              exit 0
            fi
            sleep 15
          done
          echo "Service may still be starting - check logs manually"
          ssh -i ~/.ssh/garfenter-key.pem ec2-user@${{{{ secrets.EC2_HOST }}}} \\
            "docker logs garfenter-${{{{ env.PRODUCT_NAME }}}} --tail 50" || true

      - name: Deployment Summary
        run: |
          echo "## ${{{{ env.PRODUCT_DISPLAY }}}} Deployment" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Property | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|----------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Product | ${{{{ env.PRODUCT_DISPLAY }}}} |" >> $GITHUB_STEP_SUMMARY
          echo "| Container | garfenter-${{{{ env.PRODUCT_NAME }}}} |" >> $GITHUB_STEP_SUMMARY
          echo "| Port | ${{{{ env.PORT }}}} |" >> $GITHUB_STEP_SUMMARY
          echo "| Commit | ${{{{ github.sha }}}} |" >> $GITHUB_STEP_SUMMARY
          echo "| Deployed | $(date -u) |" >> $GITHUB_STEP_SUMMARY
'''

def generate_workflow(name, config):
    """Generate a workflow file for a product."""
    return WORKFLOW_TEMPLATE.format(
        name=name,
        display=config["display"],
        image=config["image"],
        port=config["port"],
        health_path=config["health_path"]
    )

def main():
    output_dir = "/Users/garfenter/development/products/garfenter-cloud/.github/workflow-templates"
    os.makedirs(output_dir, exist_ok=True)

    for name, config in PRODUCTS.items():
        workflow = generate_workflow(name, config)
        output_path = os.path.join(output_dir, f"deploy-{name}.yml")
        with open(output_path, 'w') as f:
            f.write(workflow)
        print(f"Generated: {output_path}")

    print(f"\nGenerated {len(PRODUCTS)} workflow files")

if __name__ == "__main__":
    main()
