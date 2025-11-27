# Garfenter Cloud - Deployment Architecture

## Vision

**Two distinct systems:**

1. **Demo Platform (garfenter.com)** - Showcase capabilities to potential customers. Single EC2, on-demand products, low cost. Self-contained.

2. **garfenter-portal** - Multi-tenant SaaS platform for clients/resellers to dynamically provision isolated environments for their end customers. Separate infrastructure, not connected to demo.

## Current Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GARFENTER CLOUD PLATFORM                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────┐ │
│  │   GitHub     │────▶│     ECR      │────▶│      EC2 Instance        │ │
│  │   Actions    │push │  (12 repos)  │pull │    (t3.medium)           │ │
│  └──────────────┘     └──────────────┘     │                          │ │
│                                             │  ┌────────────────────┐  │ │
│  ┌──────────────┐                          │  │   Always Running   │  │ │
│  │  Terraform   │─────────────────────────▶│  │  - nginx (landing) │  │ │
│  │    (IaC)     │ provisions & configures  │  │  - postgres        │  │ │
│  └──────────────┘                          │  │  - mysql           │  │ │
│                                             │  │  - redis           │  │ │
│  ┌──────────────┐                          │  │  - startup-api     │  │ │
│  │ Cloudflare   │                          │  └────────────────────┘  │ │
│  │    DNS       │◀─────────────────────────│                          │ │
│  │ *.garfenter  │  wildcard DNS            │  ┌────────────────────┐  │ │
│  └──────────────┘                          │  │   On-Demand Only   │  │ │
│                                             │  │  (one at a time)   │  │ │
│                                             │  │  - tienda          │  │ │
│                                             │  │  - mercado         │  │ │
│                                             │  │  - pos             │  │ │
│                                             │  │  - contable        │  │ │
│                                             │  │  - erp             │  │ │
│                                             │  │  - clientes        │  │ │
│                                             │  │  - inmuebles       │  │ │
│                                             │  │  - campo           │  │ │
│                                             │  │  - banco           │  │ │
│                                             │  │  - salud           │  │ │
│                                             │  │  - educacion       │  │ │
│                                             │  └────────────────────┘  │ │
│                                             └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## The 12 Products

| Product    | Description          | Base Image            | Port | Database   |
|------------|----------------------|-----------------------|------|------------|
| landing    | Landing page         | nginx + astro build   | 80   | -          |
| tienda     | E-commerce           | Saleor                | 8000 | PostgreSQL |
| mercado    | Marketplace          | Spurt Commerce        | 8000 | MySQL      |
| pos        | Point of Sale        | OpenSourcePOS         | 80   | MySQL      |
| contable   | Accounting           | Bigcapital            | 3000 | PostgreSQL |
| erp        | ERP                  | Odoo 17               | 8069 | PostgreSQL |
| clientes   | CRM                  | Twenty CRM            | 3000 | PostgreSQL |
| inmuebles  | Property Management  | Condo                 | 3000 | PostgreSQL |
| campo      | Farm Management      | farmOS                | 80   | PostgreSQL |
| banco      | Banking/Fintech      | Apache Fineract       | 8443 | MySQL      |
| salud      | Health/HMIS          | HMIS                  | 80   | MySQL      |
| educacion  | Education/LMS        | Canvas LMS            | 3000 | PostgreSQL |

## Component Responsibilities

### 1. Terraform (Infrastructure as Code)
- Provisions EC2 instance, ECR repositories, IAM roles
- Configures image tags via `image_tags` variable
- Injects environment variables via user-data template
- **NO manual SSH commands required**

### 2. GitHub Actions (CI/CD)
- Builds Docker images on push to main
- Pushes to ECR with commit SHA + `latest` tags
- Deploys to EC2 via SSH (for landing page)
- Uses OIDC authentication (no static AWS credentials)

### 3. startup-api.py (On-Demand Orchestration)
- REST API for product lifecycle management
- Endpoints:
  - `POST /api/start/<product>` - Start a product (stops others)
  - `POST /api/stop/<product>` - Stop a product
  - `GET /api/status` - Get all product statuses
  - `GET /api/status/<product>` - Get specific product status
- Pulls images from ECR based on environment tags
- Memory-limited containers (512MB per product)

### 4. nginx (Reverse Proxy)
- Serves landing page
- Routes `<product>.garfenter.com` to product containers
- Auto-start feature: Shows "Starting..." page and triggers API

## Environment Configuration

All products are configured via environment variables:

```bash
# Core secrets (from Terraform)
POSTGRES_PASSWORD=***
MYSQL_PASSWORD=***
JWT_SECRET=***

# ECR configuration
ECR_REGISTRY=144656353217.dkr.ecr.us-east-1.amazonaws.com

# Image tags (controlled by Terraform or CI/CD)
LANDING_TAG=latest
TIENDA_TAG=latest
MERCADO_TAG=latest
# ... etc for all 12 products
```

## Deployment Flows

### Flow 1: Landing Page (Automated)
```
Push to main → GitHub Actions → Build → ECR Push → SSH Deploy → Live
```

### Flow 2: Products (On-Demand via API)
```
User visits pos.garfenter.com
    ↓
nginx sees 502 (container not running)
    ↓
Shows "Starting..." page + calls /api/start/pos
    ↓
startup-api stops other products (if any)
    ↓
startup-api pulls ECR image + starts container
    ↓
User refreshes → product is running
```

### Flow 3: Product Updates (Terraform)
```
CI/CD pushes new image → Update terraform.tfvars → terraform apply
    ↓
EC2 user-data regenerates with new tags
    ↓
Next product start will pull new version
```

---

## Alignment Assessment

### What's Working Well

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Containerized products | ✅ | All 12 products as Docker containers |
| Environment variables | ✅ | All config via .env, no hardcoded values |
| Cost-effective demo | ✅ | Single EC2 t3.medium (~$30/month) |
| On-demand startup | ✅ | startup-api.py with REST endpoints |
| Infrastructure as Code | ✅ | Terraform manages all AWS resources |
| CI/CD pipeline | ✅ | GitHub Actions → ECR → Deploy |
| Version control | ✅ | Image tags controlled via Terraform |

### Future Demo Improvements (Optional)

| Feature | Current | Nice to Have |
|---------|---------|--------------|
| Concurrent products | One at a time | Allow 2-3 for comparison demos |
| Auto-shutdown | None | Idle timeout after 30 min |
| Health checks | Basic | Show container logs in UI |
| Analytics | None | Track which products are popular |

---

## garfenter-portal (Separate System)

**Purpose:** Multi-tenant SaaS platform for clients, tenants, and resellers to dynamically create isolated environments for their end customers.

**NOT** connected to the demo. Completely separate infrastructure.

### Portal Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GARFENTER-PORTAL                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐                                                        │
│  │  Portal Frontend │  React/Next.js dashboard for clients/resellers        │
│  └────────┬─────────┘                                                        │
│           │                                                                  │
│  ┌────────▼─────────┐     ┌─────────────────────────────────────────────┐   │
│  │   Portal API     │────▶│           Provisioning Engine               │   │
│  │   (garfenter-    │     │                                             │   │
│  │    portal)       │     │  - Terraform modules per product            │   │
│  └──────────────────┘     │  - ECR images (same as demo)                │   │
│                           │  - Isolated infrastructure per customer      │   │
│                           └─────────────────────────────────────────────┘   │
│                                           │                                  │
│                    ┌──────────────────────┼──────────────────────┐          │
│                    ▼                      ▼                      ▼          │
│           ┌───────────────┐      ┌───────────────┐      ┌───────────────┐  │
│           │ Customer A    │      │ Customer B    │      │ Customer C    │  │
│           │ Environment   │      │ Environment   │      │ Environment   │  │
│           │               │      │               │      │               │  │
│           │ tienda +      │      │ erp +         │      │ pos +         │  │
│           │ contable      │      │ clientes      │      │ banco         │  │
│           │               │      │               │      │               │  │
│           │ acme.garfenter│      │ xyz.garfenter │      │ 123.garfenter │  │
│           └───────────────┘      └───────────────┘      └───────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Shared Components Between Demo & Portal

| Component | Shared | Notes |
|-----------|--------|-------|
| ECR images | ✅ Yes | Same Docker images for both |
| Terraform modules | ✅ Yes | Reusable EC2/Docker provisioning |
| Product configs | ✅ Yes | Environment variables, ports, etc. |
| Infrastructure | ❌ No | Demo is isolated from customer envs |
| Databases | ❌ No | Each customer gets own DBs |

### What Portal Needs from garfenter-cloud

1. **Reusable Terraform modules** - To provision customer environments
2. **Product definitions** - Container configs, ports, env vars
3. **Docker images in ECR** - Same images demo uses
4. **Deployment scripts** - Templatized for per-customer customization

### Portal Provisioning Flow

```
Reseller creates customer via Portal
    │
    ▼
Portal calls Provisioning Engine
    │
    ▼
Engine runs Terraform with:
    - customer_id = "acme"
    - products = ["tienda", "contable"]
    - domain = "acme.garfenter.com"
    │
    ▼
New EC2 instance provisioned
    - Uses same user-data.sh template
    - Pulls images from ECR
    - Isolated databases
    │
    ▼
Customer gets their own URLs:
    - tienda.acme.garfenter.com
    - contable.acme.garfenter.com
```

### Terraform Module Structure for Portal

```hcl
# modules/customer-environment/main.tf
module "customer_env" {
  source = "../garfenter-cloud/terraform"

  customer_id     = var.customer_id
  products        = var.products          # ["tienda", "pos"]
  domain_prefix   = var.customer_id       # acme.garfenter.com
  instance_type   = var.tier == "basic" ? "t3.small" : "t3.medium"

  # Pull from shared ECR
  ecr_registry    = "144656353217.dkr.ecr.us-east-1.amazonaws.com"
  image_tags      = var.image_tags
}
```

---

## Cost Analysis

### Demo Platform (garfenter.com)

| Resource | Monthly Cost |
|----------|-------------|
| EC2 t3.medium (on-demand) | ~$30 |
| EBS 50GB gp3 | ~$4 |
| ECR storage (~2GB) | ~$0.20 |
| Data transfer | ~$5 |
| **Total** | **~$40/month** |

### Customer Environments (via Portal)

| Tier | Instance | Est. Monthly Cost per Customer |
|------|----------|-------------------------------|
| Basic (1-2 products) | t3.small | ~$20 |
| Standard (3-5 products) | t3.medium | ~$40 |
| Enterprise (all products) | t3.large | ~$80 |

**Note:** Portal provisions isolated environments. Each customer = separate EC2 + databases.

---

## Next Steps

### For Demo (garfenter.com)
1. **Test all 12 products** - Ensure all start correctly from ECR
2. **Add idle timeout** - Auto-stop after 30 min inactivity (cost control)
3. **Improve loading page** - Better UX while products start

### For Portal (garfenter-portal)
1. **Modularize Terraform** - Extract reusable modules for customer provisioning
2. **Create product definitions file** - JSON/YAML with all product configs
3. **Design provisioning API** - How portal triggers Terraform
4. **Plan multi-product support** - Customers may want 2-3 products together
5. **Define pricing tiers** - t3.small vs t3.medium based on products/usage

---

## File Reference

| File | Purpose |
|------|---------|
| `terraform/ecr.tf` | ECR repositories for all 12 products |
| `terraform/ec2.tf` | EC2 instance configuration |
| `terraform/user-data.sh` | Bootstrap script with IaC |
| `terraform/variables.tf` | All configurable parameters |
| `docker/init-scripts/startup-api.py` | On-demand product API |
| `docker/init-scripts/docker-compose.startup.yml` | Core services |
| `landing/.github/workflows/deploy.yml` | CI/CD pipeline |
