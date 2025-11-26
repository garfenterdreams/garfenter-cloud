#!/bin/bash
# Garfenter Cloud - Setup Script
# Downloads and configures all platform files
# Called by user-data.sh bootstrap

set -e

GH=$1
DOMAIN=$2

echo "=== Setting up Garfenter platform files ==="

# Create directory structure
mkdir -p $GH/{nginx/conf.d,startup,www,data/postgres,data/mysql}

# Download files from GitHub
REPO_URL="https://raw.githubusercontent.com/garfenterdreams/garfenter-cloud/main/docker/init-scripts"

# Docker Compose
curl -sL "$REPO_URL/docker-compose.startup.yml" -o $GH/docker-compose.yml

# PostgreSQL Init
curl -sL "$REPO_URL/postgres/00-create-databases.sql" -o $GH/init-postgres.sql

# MySQL Init
curl -sL "$REPO_URL/mysql/00-create-databases.sql" -o $GH/init-mysql.sql

# Nginx main config
curl -sL "$REPO_URL/nginx.conf" -o $GH/nginx/nginx.conf

# Startup API
curl -sL "$REPO_URL/startup-api.py" -o $GH/startup/api.py

# Landing Page
curl -sL "$REPO_URL/landing.html" -o $GH/www/index.html

# Generate Nginx default config with all 11 products
cat > $GH/nginx/conf.d/default.conf << EOF
server {
    listen 80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    location / { try_files \$uri \$uri/ /index.html; }
    location /api/ { proxy_pass http://garfenter-startup:5000; proxy_set_header Host \$host; }
    location /health { return 200 "OK"; }
}
EOF

# Generate product server blocks
for p in tienda mercado pos contable erp clientes inmuebles campo banco salud educacion; do
  case $p in
    erp) PORT=8069 ;;
    tienda|mercado) PORT=8000 ;;
    contable|clientes|inmuebles|educacion) PORT=3000 ;;
    banco) PORT=8443 ;;
    *) PORT=80 ;;
  esac
  cat >> $GH/nginx/conf.d/default.conf << EOF
server {
    listen 80;
    server_name $p.$DOMAIN;
    location / {
        set \$backend garfenter-$p;
        proxy_pass http://\$backend:$PORT;
        proxy_set_header Host \$host;
        proxy_connect_timeout 3s;
        proxy_read_timeout 300s;
        proxy_intercept_errors on;
        error_page 502 503 504 =200 @loading;
    }
    location @loading {
        default_type text/html;
        return 200 '<html><head><meta http-equiv="refresh" content="5"><title>Loading...</title></head><body style="background:#1a1a2e;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif"><div><h1>Starting $p...</h1><p>Please wait...</p></div><script>fetch("/api/start/$p",{method:"POST"})</script></body></html>';
    }
    location /api/ { proxy_pass http://garfenter-startup:5000; proxy_set_header Host \$host; }
}
EOF
done

echo "=== Setup complete ==="
