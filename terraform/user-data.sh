#!/bin/bash
# Garfenter Cloud Platform - Minimal Bootstrap
# Downloads configuration from GitHub - Infrastructure as Code
set -e
exec > >(tee /var/log/garfenter-bootstrap.log) 2>&1
echo "=== Garfenter Bootstrap $(date) ==="

# Terraform variables
PG_PASS="${postgres_password}"
MYSQL_PASS="${mysql_password}"
JWT_SECRET="${jwt_secret}"
DOMAIN="${domain_name}"
GH=/home/ec2-user/garfenter
REPO="https://raw.githubusercontent.com/garfenterdreams/garfenter-cloud/main/docker/init-scripts"

# System setup
dnf update -y
dnf install -y --allowerasing docker git curl
systemctl start docker && systemctl enable docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
usermod -aG docker ec2-user

# Swap (4GB)
fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

# Create directories
mkdir -p $GH/{nginx/conf.d,startup,www,data/postgres,data/mysql}

# Environment file
cat > $GH/.env << EOF
POSTGRES_PASSWORD=$PG_PASS
MYSQL_PASSWORD=$MYSQL_PASS
JWT_SECRET=$JWT_SECRET
DOMAIN_NAME=$DOMAIN
EOF

# Clone configuration from GitHub
git clone --depth 1 https://github.com/garfenterdreams/garfenter-cloud.git /tmp/garfenter-cloud
cp /tmp/garfenter-cloud/docker/init-scripts/docker-compose.startup.yml $GH/docker-compose.yml
cp /tmp/garfenter-cloud/docker/init-scripts/postgres/00-create-databases.sql $GH/init-postgres.sql
cp /tmp/garfenter-cloud/docker/init-scripts/mysql/00-create-databases.sql $GH/init-mysql.sql
cp /tmp/garfenter-cloud/docker/init-scripts/nginx.conf $GH/nginx/nginx.conf
cp /tmp/garfenter-cloud/docker/init-scripts/startup-api.py $GH/startup/api.py
rm -rf /tmp/garfenter-cloud

# Placeholder for www - real landing deployed by GitHub Actions from garfenterdreams/landing
cat > $GH/www/index.html << 'LANDING'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta http-equiv="refresh" content="30">
<title>Garfenter</title><style>body{background:#1a1a2e;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui}</style>
</head><body><div style="text-align:center"><h1>Garfenter</h1><p>Deploying landing page...</p></div></body></html>
LANDING

# Generate Nginx config
cat > $GH/nginx/conf.d/default.conf << 'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
    location /api/ { proxy_pass http://garfenter-startup:5000; proxy_set_header Host $host; }
    location /health { return 200 "OK"; }
}
NGINX

# Generate product server blocks
for p in tienda mercado pos contable erp clientes inmuebles campo banco salud educacion; do
  case $p in erp) PORT=8069;; tienda|mercado) PORT=8000;; contable|clientes|inmuebles|educacion) PORT=3000;; banco) PORT=8443;; *) PORT=80;; esac
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
        return 200 '<html><head><meta http-equiv="refresh" content="5"></head><body style="background:#1a1a2e;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh"><h1>Starting $p...</h1><script>fetch("/api/start/$p",{method:"POST"})</script></body></html>';
    }
    location /api/ { proxy_pass http://garfenter-startup:5000; proxy_set_header Host \$host; }
}
EOF
done

chown -R ec2-user:ec2-user $GH
cd $GH && docker compose up -d

echo "=== Bootstrap Complete $(date) ==="
