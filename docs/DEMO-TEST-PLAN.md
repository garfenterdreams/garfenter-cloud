# Garfenter Demo - Product Test Plan

## Overview

This document outlines the test plan to verify all 12 products are working correctly for the demo platform at garfenter.com.

## Test Environment

- **EC2 Instance**: 18.214.229.161
- **ECR Registry**: 144656353217.dkr.ecr.us-east-1.amazonaws.com
- **Domain**: *.garfenter.com (Cloudflare DNS)
- **Startup API**: http://18.214.229.161/api/

## Products to Test

| # | Product | URL | Port | Database | Base Image |
|---|---------|-----|------|----------|------------|
| 1 | landing | garfenter.com | 80 | - | nginx/astro |
| 2 | tienda | tienda.garfenter.com | 8000 | PostgreSQL | Saleor |
| 3 | mercado | mercado.garfenter.com | 8000 | MySQL | Spurt Commerce |
| 4 | pos | pos.garfenter.com | 80 | MySQL | OpenSourcePOS |
| 5 | contable | contable.garfenter.com | 3000 | PostgreSQL | Bigcapital |
| 6 | erp | erp.garfenter.com | 8069 | PostgreSQL | Odoo 17 |
| 7 | clientes | clientes.garfenter.com | 3000 | PostgreSQL | Twenty CRM |
| 8 | inmuebles | inmuebles.garfenter.com | 3000 | PostgreSQL | ERPNext/Frappe |
| 9 | campo | campo.garfenter.com | 80 | PostgreSQL | farmOS |
| 10 | banco | banco.garfenter.com | 8443 | MySQL | Apache Fineract |
| 11 | salud | salud.garfenter.com | 80 | MySQL | HMIS |
| 12 | educacion | educacion.garfenter.com | 3000 | PostgreSQL | Canvas LMS |

---

## Phase 1: Infrastructure Verification

### 1.1 ECR Images Exist
```bash
# Check all ECR repositories have images
for repo in landing tienda mercado pos erp educacion contable clientes inmuebles campo banco salud; do
  echo -n "$repo: "
  aws ecr describe-images --repository-name "garfenter/$repo" --query 'imageDetails | length(@)' --output text
done
```

**Expected**: Each repo should have at least 1 image

### 1.2 EC2 Startup API Running
```bash
curl -s http://18.214.229.161/api/status | jq .
```

**Expected**: Returns JSON with all product statuses

### 1.3 Core Services Running
```bash
ssh ec2-user@18.214.229.161 "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

**Expected**: nginx, postgres, mysql, redis, startup-api all running

---

## Phase 2: Landing Page Test

### 2.1 Landing Page Loads
```bash
curl -s -o /dev/null -w "%{http_code}" https://garfenter.com
```

**Expected**: 200

### 2.2 Landing Page Content
```bash
curl -s https://garfenter.com | grep -i "garfenter"
```

**Expected**: Contains Garfenter branding

---

## Phase 3: Product Startup Tests

For each product, test the following sequence:

### Test Sequence per Product

1. **Start Product via API**
```bash
curl -X POST http://18.214.229.161/api/start/<product>
```

2. **Wait for Container** (30-60 seconds)
```bash
sleep 60
```

3. **Check Container Running**
```bash
curl -s http://18.214.229.161/api/status/<product>
```

4. **HTTP Health Check**
```bash
curl -s -o /dev/null -w "%{http_code}" https://<product>.garfenter.com
```

5. **Stop Product**
```bash
curl -X POST http://18.214.229.161/api/stop/<product>
```

---

## Phase 4: Individual Product Tests

### 4.1 Tienda (Saleor E-commerce)
```bash
# Start
curl -X POST http://18.214.229.161/api/start/tienda
sleep 60

# Verify
curl -s -o /dev/null -w "%{http_code}" https://tienda.garfenter.com
# Expected: 200 or 302

# Check GraphQL endpoint
curl -s https://tienda.garfenter.com/graphql/ -H "Content-Type: application/json" -d '{"query":"{ __typename }"}' | head -c 100
```

### 4.2 Mercado (Spurt Marketplace)
```bash
curl -X POST http://18.214.229.161/api/start/mercado
sleep 60
curl -s -o /dev/null -w "%{http_code}" https://mercado.garfenter.com
# Expected: 200
```

### 4.3 POS (OpenSourcePOS)
```bash
curl -X POST http://18.214.229.161/api/start/pos
sleep 60
curl -s -o /dev/null -w "%{http_code}" https://pos.garfenter.com
# Expected: 200 or 302 (redirect to login)
```

### 4.4 Contable (Bigcapital Accounting)
```bash
curl -X POST http://18.214.229.161/api/start/contable
sleep 60
curl -s -o /dev/null -w "%{http_code}" https://contable.garfenter.com
# Expected: 200
```

### 4.5 ERP (Odoo)
```bash
curl -X POST http://18.214.229.161/api/start/erp
sleep 90  # Odoo takes longer to start
curl -s -o /dev/null -w "%{http_code}" https://erp.garfenter.com
# Expected: 200 or 303
```

### 4.6 Clientes (Twenty CRM)
```bash
curl -X POST http://18.214.229.161/api/start/clientes
sleep 60
curl -s -o /dev/null -w "%{http_code}" https://clientes.garfenter.com
# Expected: 200
```

### 4.7 Inmuebles (ERPNext Real Estate)
```bash
curl -X POST http://18.214.229.161/api/start/inmuebles
sleep 90  # Frappe takes longer
curl -s -o /dev/null -w "%{http_code}" https://inmuebles.garfenter.com
# Expected: 200
```

### 4.8 Campo (farmOS)
```bash
curl -X POST http://18.214.229.161/api/start/campo
sleep 60
curl -s -o /dev/null -w "%{http_code}" https://campo.garfenter.com
# Expected: 200 or 302
```

### 4.9 Banco (Apache Fineract)
```bash
curl -X POST http://18.214.229.161/api/start/banco
sleep 60
curl -s -o /dev/null -w "%{http_code}" https://banco.garfenter.com
# Expected: 200 (API) or custom page
```

### 4.10 Salud (HMIS Healthcare)
```bash
curl -X POST http://18.214.229.161/api/start/salud
sleep 60
curl -s -o /dev/null -w "%{http_code}" https://salud.garfenter.com
# Expected: 200 or 302
```

### 4.11 Educacion (Canvas LMS)
```bash
curl -X POST http://18.214.229.161/api/start/educacion
sleep 90  # Canvas takes longer
curl -s -o /dev/null -w "%{http_code}" https://educacion.garfenter.com
# Expected: 200 or 302
```

---

## Phase 5: Automated Test Script

### Full Test Script
```bash
#!/bin/bash
# test-all-products.sh

EC2_IP="18.214.229.161"
PRODUCTS="tienda mercado pos contable erp clientes inmuebles campo banco salud educacion"

echo "=== Garfenter Demo Product Tests ==="
echo "Started: $(date)"
echo ""

# Test landing page
echo "=== Testing Landing Page ==="
status=$(curl -s -o /dev/null -w "%{http_code}" https://garfenter.com)
if [ "$status" = "200" ]; then
  echo "PASS: Landing page returns 200"
else
  echo "FAIL: Landing page returns $status"
fi
echo ""

# Test each product
for product in $PRODUCTS; do
  echo "=== Testing $product ==="

  # Start
  echo "Starting $product..."
  curl -s -X POST http://$EC2_IP/api/start/$product > /dev/null

  # Wait
  echo "Waiting 60 seconds for startup..."
  sleep 60

  # Check status
  status=$(curl -s http://$EC2_IP/api/status/$product | jq -r '.status')
  echo "Container status: $status"

  # HTTP check
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://$product.garfenter.com)
  if [ "$http_code" = "200" ] || [ "$http_code" = "302" ] || [ "$http_code" = "303" ]; then
    echo "PASS: $product returns HTTP $http_code"
  else
    echo "FAIL: $product returns HTTP $http_code"
  fi

  # Stop
  echo "Stopping $product..."
  curl -s -X POST http://$EC2_IP/api/stop/$product > /dev/null
  sleep 5

  echo ""
done

echo "=== Tests Complete ==="
echo "Finished: $(date)"
```

---

## Test Results Template

| Product | ECR Image | Container Start | HTTP Response | Notes |
|---------|-----------|-----------------|---------------|-------|
| landing | ✅/❌ | N/A | ✅/❌ (code) | |
| tienda | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| mercado | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| pos | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| contable | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| erp | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| clientes | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| inmuebles | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| campo | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| banco | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| salud | ✅/❌ | ✅/❌ | ✅/❌ (code) | |
| educacion | ✅/❌ | ✅/❌ | ✅/❌ (code) | |

---

## Success Criteria

### Minimum Viable Demo
- [ ] Landing page loads at garfenter.com
- [ ] At least 6 products start successfully
- [ ] Products accessible via subdomain URLs
- [ ] Startup API responds correctly

### Full Demo Ready
- [ ] All 12 products have ECR images
- [ ] All 12 products start via API
- [ ] All 12 products respond to HTTP requests
- [ ] Products can be started/stopped on demand

---

## Troubleshooting

### Product Won't Start
```bash
# Check container logs
ssh ec2-user@18.214.229.161 "docker logs garfenter-<product>"

# Check if image exists
ssh ec2-user@18.214.229.161 "docker images | grep <product>"

# Manual pull from ECR
ssh ec2-user@18.214.229.161 "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 144656353217.dkr.ecr.us-east-1.amazonaws.com && docker pull 144656353217.dkr.ecr.us-east-1.amazonaws.com/garfenter/<product>:latest"
```

### HTTP 502/504 Errors
- Product may still be starting up (wait longer)
- Check nginx proxy configuration
- Check product container logs

### Database Connection Issues
```bash
# Check database containers
ssh ec2-user@18.214.229.161 "docker ps | grep -E 'postgres|mysql'"

# Check database logs
ssh ec2-user@18.214.229.161 "docker logs garfenter-postgres"
ssh ec2-user@18.214.229.161 "docker logs garfenter-mysql"
```

---

## Test Results - 2025-11-27

### Phase 1: Infrastructure Verification

| Check | Status | Notes |
|-------|--------|-------|
| ECR Images Exist | PARTIAL | 8/12 repos have images |
| EC2 Startup API | PASS | API responds correctly |
| Core Services | PASS | nginx running, API responding |

### ECR Image Status

| Product | ECR Images | GitHub Workflow | Notes |
|---------|------------|-----------------|-------|
| landing | 8 images | SUCCESS | Working |
| tienda | 5 images | SUCCESS | Working |
| mercado | NO IMAGES | FAILED | Dockerfile build failed |
| pos | NO IMAGES | FAILED | Dockerfile build failed |
| erp | NO IMAGES | IN_PROGRESS | Large repo, slow build |
| educacion | 3 images | SUCCESS | Working |
| contable | 3 images | SUCCESS | Working |
| clientes | 3 images | SUCCESS | Working |
| inmuebles | NO IMAGES | FAILED | Dockerfile build failed |
| campo | 3 images | SUCCESS | Working |
| banco | 3 images | SUCCESS | Working |
| salud | 3 images | SUCCESS | Working |

### Phase 2: Landing Page

| Test | Status | Result |
|------|--------|--------|
| HTTP Response | PASS | 200 |
| Garfenter Branding | PASS | Present |

### Phase 3: Startup API Tests

| Product | API Start | Container Status | HTTP Response | Issue |
|---------|-----------|------------------|---------------|-------|
| tienda | starting | false | 200 | Nginx placeholder only |
| educacion | starting | false | 200 | Nginx placeholder only |
| contable | ERROR | false | 200 | Pulls from Docker Hub, not ECR |
| clientes | starting | false | 200 | Nginx placeholder only |
| campo | ERROR | false | 200 | Port 80 conflict |
| banco | starting | false | 200 | Nginx placeholder only |
| salud | ERROR | false | 200 | Pulls from Docker Hub, not ECR |

### Critical Issues Found

1. **Startup API Configuration**: The startup-api.py is configured to pull images from Docker Hub instead of ECR. Needs to be updated to pull from `144656353217.dkr.ecr.us-east-1.amazonaws.com/garfenter/<product>:latest`

2. **Failed GitHub Workflows**: 3 products have failed builds:
   - mercado (Spurt Commerce)
   - pos (OpenSourcePOS)
   - inmuebles (ERPNext)

3. **Port Conflicts**: campo (farmOS) fails to start due to port 80 already allocated

4. **HTTP 200 Responses**: All products return HTTP 200, but this is from nginx placeholder pages, not actual products

### Summary

| Criteria | Status |
|----------|--------|
| Landing page loads | PASS |
| At least 6 products have ECR images | PASS (8/12) |
| Products accessible via subdomain URLs | PARTIAL (nginx placeholders) |
| Startup API responds correctly | PASS |
| Products actually start via API | FAIL |

### Next Steps

1. **Update startup-api.py** to pull from ECR instead of Docker Hub
2. **Fix failed workflows** for mercado, pos, inmuebles (check Dockerfiles)
3. **Resolve port conflicts** in docker-compose configuration
4. **Wait for erp workflow** to complete
5. **Re-test** after fixes
