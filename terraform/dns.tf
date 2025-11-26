# Cloudflare DNS Configuration for garfenter.com
# Creates subdomains for all 11 products + SSO

# Get the Cloudflare zone for garfenter.com
data "cloudflare_zone" "garfenter" {
  name = "garfenter.com"
}

# Local variable for all product subdomains
locals {
  subdomains = {
    # Main domain
    "demo"      = "Landing page and dashboard"

    # SSO
    "sso"       = "Keycloak SSO Server"

    # Commerce Suite (Group A)
    "tienda"    = "Saleor E-commerce"
    "mercado"   = "Spurt Commerce Marketplace"
    "pos"       = "Open Source POS"
    "contable"  = "Bigcapital Accounting"

    # Enterprise Suite (Group B)
    "erp"       = "Odoo ERP"
    "clientes"  = "Twenty CRM"
    "inmuebles" = "Condo Real Estate"
    "campo"     = "farmOS Agriculture"

    # Services Suite (Group C)
    "banco"     = "Apache Fineract Banking"
    "salud"     = "HMIS Healthcare"

    # Education Suite (Group D)
    "educacion" = "Canvas LMS Education"
  }
}

# Create A records for all subdomains pointing to the EC2 Elastic IP
resource "cloudflare_record" "garfenter_subdomains" {
  for_each = local.subdomains

  zone_id = data.cloudflare_zone.garfenter.id
  name    = each.key
  value   = aws_eip.garfenter.public_ip
  type    = "A"
  ttl     = 1    # Auto (required when proxied=true)
  proxied = true # Enable Cloudflare proxy for SSL and DDoS protection

  comment = "Garfenter ${each.value}"
}

# Wildcard record for any additional subdomains
resource "cloudflare_record" "garfenter_wildcard" {
  zone_id = data.cloudflare_zone.garfenter.id
  name    = "*"
  value   = aws_eip.garfenter.public_ip
  type    = "A"
  ttl     = 300
  proxied = false # Wildcards can't be proxied on free plan

  comment = "Garfenter wildcard for additional services"
}

# ============================================
# Ephemeral Preview Environments
# Pattern: preview-<code>.<product>.garfenter.com
# Example: preview-abc123.erp.garfenter.com
# ============================================

# Product subdomains that support preview environments
locals {
  preview_enabled_products = [
    "erp",       # Odoo
    "tienda",    # Saleor
    "mercado",   # Spurt Commerce
    "clientes",  # Twenty CRM
    "contable",  # Bigcapital
    "inmuebles", # Condo
    "pos",       # OSPOS
    "salud",     # HMIS
    "banco",     # Fineract
    "campo",     # farmOS
    "educacion", # Canvas
  ]
}

# Wildcard records for preview environments (*.product.garfenter.com)
resource "cloudflare_record" "garfenter_preview_wildcards" {
  for_each = toset(local.preview_enabled_products)

  zone_id = data.cloudflare_zone.garfenter.id
  name    = "*.${each.key}"
  value   = aws_eip.garfenter.public_ip
  type    = "A"
  ttl     = 60  # Short TTL for ephemeral environments
  proxied = false # Wildcards can't be proxied on free plan

  comment = "Preview environments for ${each.key}"
}

# Root domain record
resource "cloudflare_record" "garfenter_root" {
  zone_id         = data.cloudflare_zone.garfenter.id
  name            = "@"
  value           = aws_eip.garfenter.public_ip
  type            = "A"
  ttl             = 1  # Auto (required when proxied=true)
  proxied         = true
  allow_overwrite = true  # Overwrite existing record

  comment = "Garfenter main domain"
}

# WWW redirect to root
resource "cloudflare_record" "garfenter_www" {
  zone_id = data.cloudflare_zone.garfenter.id
  name    = "www"
  value   = aws_eip.garfenter.public_ip
  type    = "A"
  ttl     = 1  # Auto (required when proxied=true)
  proxied = true

  comment = "Garfenter www redirect"
}

# Note: SSL/TLS settings must be configured manually in Cloudflare Dashboard
# Go to SSL/TLS > Overview and set to "Flexible" mode
