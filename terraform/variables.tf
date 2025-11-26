# Variables for Garfenter Cloud Infrastructure

# ============================================
# AWS Credentials
# ============================================
variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

# ============================================
# Cloudflare Credentials
# ============================================
variable "cloudflare_api_token" {
  description = "Cloudflare API Token with DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  default     = ""
}

# ============================================
# AWS Configuration
# ============================================
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, demo, prod)"
  type        = string
  default     = "demo"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"  # 2 vCPU, 4GB RAM
}

variable "spot_max_price" {
  description = "Maximum price for spot instance (USD per hour)"
  type        = string
  default     = "0.02"  # ~$15/month max
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair to use"
  type        = string
}

variable "admin_ip" {
  description = "IP address allowed for SSH access (CIDR format)"
  type        = string
  default     = "0.0.0.0/0"  # CHANGE THIS to your IP for security
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 50
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "50"
}

variable "alert_email" {
  description = "Email address for budget alerts"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the demo platform (user-provided)"
  type        = string
  default     = "garfenter.demo"
}

# Database credentials (stored in .env.secrets, referenced here)
variable "postgres_password" {
  description = "PostgreSQL root password"
  type        = string
  sensitive   = true
}

variable "mysql_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret for API authentication across all products"
  type        = string
  sensitive   = true
}

# ============================================
# ECR Image Tags
# GitHub Actions pushes images, Terraform deploys specific versions
# ============================================
variable "image_tags" {
  description = "Docker image tags for each product (set by CI/CD pipeline)"
  type = object({
    landing   = string
    tienda    = string
    mercado   = string
    pos       = string
    contable  = string
    erp       = string
    clientes  = string
    inmuebles = string
    campo     = string
    banco     = string
    salud     = string
    educacion = string
  })
  default = {
    landing   = "latest"
    tienda    = "latest"
    mercado   = "latest"
    pos       = "latest"
    contable  = "latest"
    erp       = "latest"
    clientes  = "latest"
    inmuebles = "latest"
    campo     = "latest"
    banco     = "latest"
    salud     = "latest"
    educacion = "latest"
  }
}
