# Outputs for Garfenter Cloud Infrastructure

output "public_ip" {
  description = "Public IP address of the demo server"
  value       = aws_eip.garfenter.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.garfenter_demo.id
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_eip.garfenter.public_ip}"
}

output "demo_urls" {
  description = "URLs for accessing the demo platform (subdomain-based)"
  value = {
    landing_page = "https://${var.domain_name}/"
    demo         = "https://demo.${var.domain_name}/"
    sso          = "https://sso.${var.domain_name}/"
    # Commerce Suite
    tienda       = "https://tienda.${var.domain_name}/"
    mercado      = "https://mercado.${var.domain_name}/"
    pos          = "https://pos.${var.domain_name}/"
    contable     = "https://contable.${var.domain_name}/"
    # Enterprise Suite
    erp          = "https://erp.${var.domain_name}/"
    clientes     = "https://clientes.${var.domain_name}/"
    inmuebles    = "https://inmuebles.${var.domain_name}/"
    campo        = "https://campo.${var.domain_name}/"
    # Services Suite
    banco        = "https://banco.${var.domain_name}/"
    salud        = "https://salud.${var.domain_name}/"
    # Education Suite
    educacion    = "https://educacion.${var.domain_name}/"
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost"
  value       = "~$35-50/month (EC2 t3.medium: $30 + EBS: $4 + EIP: $3.65 + Transfer: ~$0.50)"
}
