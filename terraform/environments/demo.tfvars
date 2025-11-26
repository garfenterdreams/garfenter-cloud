# Garfenter Demo Environment Configuration
# ==========================================
# Copy to terraform.tfvars and fill in sensitive values

aws_region           = "us-east-1"
environment          = "demo"
instance_type        = "t3.medium"
spot_max_price       = "0.02"
root_volume_size     = 50
monthly_budget_limit = "50"

# REQUIRED: Fill in these values
ssh_key_name         = "garfenter-demo-key"
admin_ip             = "YOUR_IP_ADDRESS/32"  # e.g., "203.0.113.50/32"
alert_email          = "your-email@example.com"
domain_name          = "your-domain.com"

# SENSITIVE: Set via environment variables or tfvars
# export TF_VAR_postgres_password="your-secure-password"
# export TF_VAR_mysql_password="your-secure-password"
# export TF_VAR_keycloak_admin_password="your-secure-password"
