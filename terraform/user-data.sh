#!/bin/bash
# Garfenter Cloud Platform - Bootstrap Script
# Downloads configuration from GitHub - Infrastructure as Code
# Authenticates with ECR and pulls images based on Terraform-provided tags
set -e
exec > >(tee /var/log/garfenter-bootstrap.log) 2>&1
echo "=== Garfenter Bootstrap $(date) ==="

# Terraform variables (injected via templatefile)
PG_PASS="${postgres_password}"
MYSQL_PASS="${mysql_password}"
JWT_SECRET="${jwt_secret}"
DOMAIN="${domain_name}"
ECR_REGISTRY="${ecr_registry}"

# Image tags (controlled by Terraform)
LANDING_TAG="${image_tags.landing}"
TIENDA_TAG="${image_tags.tienda}"
MERCADO_TAG="${image_tags.mercado}"
POS_TAG="${image_tags.pos}"
CONTABLE_TAG="${image_tags.contable}"
ERP_TAG="${image_tags.erp}"
CLIENTES_TAG="${image_tags.clientes}"
INMUEBLES_TAG="${image_tags.inmuebles}"
CAMPO_TAG="${image_tags.campo}"
BANCO_TAG="${image_tags.banco}"
SALUD_TAG="${image_tags.salud}"
EDUCACION_TAG="${image_tags.educacion}"

GH=/home/ec2-user/garfenter

# System setup
dnf update -y
dnf install -y --allowerasing docker git curl awscli
systemctl start docker && systemctl enable docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
usermod -aG docker ec2-user

# Swap (4GB)
fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

# Create directories
mkdir -p $GH/{nginx/conf.d,startup,data/postgres,data/mysql,data/mongo}

# Authenticate with ECR (uses instance profile)
echo "=== Authenticating with ECR ==="
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

# Setup ECR credential helper for automatic re-authentication
mkdir -p /root/.docker
cat > /root/.docker/config.json << DOCKERCFG
{
  "credHelpers": {
    "$ECR_REGISTRY": "ecr-login"
  }
}
DOCKERCFG

# Install ECR credential helper
curl -Lo /usr/local/bin/docker-credential-ecr-login https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/0.7.1/linux-amd64/docker-credential-ecr-login
chmod +x /usr/local/bin/docker-credential-ecr-login

# Environment file with ECR registry and image tags
cat > $GH/.env << EOF
POSTGRES_PASSWORD=$PG_PASS
MYSQL_PASSWORD=$MYSQL_PASS
JWT_SECRET=$JWT_SECRET
DOMAIN_NAME=$DOMAIN
ECR_REGISTRY=$ECR_REGISTRY
LANDING_TAG=$LANDING_TAG
TIENDA_TAG=$TIENDA_TAG
MERCADO_TAG=$MERCADO_TAG
POS_TAG=$POS_TAG
CONTABLE_TAG=$CONTABLE_TAG
ERP_TAG=$ERP_TAG
CLIENTES_TAG=$CLIENTES_TAG
INMUEBLES_TAG=$INMUEBLES_TAG
CAMPO_TAG=$CAMPO_TAG
BANCO_TAG=$BANCO_TAG
SALUD_TAG=$SALUD_TAG
EDUCACION_TAG=$EDUCACION_TAG
EOF

# Clone configuration from GitHub
git clone --depth 1 https://github.com/garfenterdreams/garfenter-cloud.git /tmp/garfenter-cloud
cp /tmp/garfenter-cloud/docker/init-scripts/docker-compose.startup.yml $GH/docker-compose.yml
cp /tmp/garfenter-cloud/docker/init-scripts/postgres/00-create-databases.sql $GH/init-postgres.sql
cp /tmp/garfenter-cloud/docker/init-scripts/mysql/00-create-databases.sql $GH/init-mysql.sql
cp /tmp/garfenter-cloud/docker/init-scripts/nginx.conf $GH/nginx/nginx.conf
cp /tmp/garfenter-cloud/docker/init-scripts/startup-api.py $GH/startup/api.py
rm -rf /tmp/garfenter-cloud

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

# Setup cron job to refresh ECR credentials every 6 hours
cat > /etc/cron.d/ecr-refresh << 'CRON'
0 */6 * * * root aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY >> /var/log/ecr-refresh.log 2>&1
CRON

chown -R ec2-user:ec2-user $GH

# Pull landing image and start services
echo "=== Pulling landing image from ECR ==="
docker pull $ECR_REGISTRY/garfenter/landing:$LANDING_TAG || echo "Landing image not yet available, nginx will use default"

cd $GH && docker compose up -d

echo "=== Bootstrap Complete $(date) ==="
