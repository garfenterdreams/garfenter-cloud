# EC2 Spot Instance Configuration for Garfenter Demo Platform

# Elastic IP (keeps IP stable even if spot instance is replaced)
resource "aws_eip" "garfenter" {
  domain = "vpc"

  tags = {
    Name = "garfenter-demo-eip"
  }
}

# EC2 Instance (On-Demand for reliability)
resource "aws_instance" "garfenter_demo" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type

  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.garfenter.id]

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    postgres_password       = var.postgres_password
    mysql_password          = var.mysql_password
    keycloak_admin_password = var.keycloak_admin_password
    jwt_secret              = var.jwt_secret
    domain_name             = var.domain_name
  }))

  tags = {
    Name = "garfenter-demo"
  }
}

# Associate Elastic IP with the instance
resource "aws_eip_association" "garfenter" {
  instance_id   = aws_instance.garfenter_demo.id
  allocation_id = aws_eip.garfenter.id
}

# CloudWatch alarm for instance health
resource "aws_cloudwatch_metric_alarm" "instance_status" {
  alarm_name          = "garfenter-instance-health"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors EC2 instance status"

  dimensions = {
    InstanceId = aws_instance.garfenter_demo.id
  }

  alarm_actions = []  # Add SNS topic ARN for notifications
}
