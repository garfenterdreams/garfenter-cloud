# ECR Repositories for Garfenter Cloud Platform
# GitHub Actions builds and pushes images here
# EC2 pulls the specified version on deploy

locals {
  # All components that need ECR repos
  ecr_repos = {
    landing   = "Landing page (nginx + static)"
    tienda    = "E-commerce (Saleor)"
    mercado   = "Marketplace (Spurt Commerce)"
    pos       = "Point of Sale (OpenSourcePOS)"
    contable  = "Accounting (Bigcapital)"
    erp       = "ERP (Odoo)"
    clientes  = "CRM (Twenty)"
    inmuebles = "Property Management (Condo)"
    campo     = "Farm Management (farmOS)"
    banco     = "Banking (Apache Fineract)"
    salud     = "Health (HMIS)"
    educacion = "Education (Canvas LMS)"
  }
}

# ECR Repository for each component
resource "aws_ecr_repository" "products" {
  for_each = local.ecr_repos

  name                 = "garfenter/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false  # Disable for cost savings
  }

  tags = {
    Name        = "garfenter-${each.key}"
    Description = each.value
  }
}

# Lifecycle policy to keep only recent images (cost control)
resource "aws_ecr_lifecycle_policy" "products" {
  for_each = local.ecr_repos

  repository = aws_ecr_repository.products[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# IAM Role for EC2 to pull from ECR
resource "aws_iam_role" "ec2_ecr" {
  name = "garfenter-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_ecr" {
  name = "garfenter-ec2-ecr-policy"
  role = aws_iam_role.ec2_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [for repo in aws_ecr_repository.products : repo.arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_ecr" {
  name = "garfenter-ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr.name
}

# OIDC Provider for GitHub Actions (to push to ECR)
data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Role for GitHub Actions to push to ECR
resource "aws_iam_role" "github_actions" {
  name = "garfenter-github-actions-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:garfenterdreams/*:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "garfenter-github-actions-ecr-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [for repo in aws_ecr_repository.products : repo.arn]
      }
    ]
  })
}
