terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
  }
  backend "s3" {
    bucket = "terraform-states-mikeacjones"
    region = "us-east-2"
    key    = "terraform.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

resource "aws_iam_policy" "reddit-bot-policy" {
  name        = "reddit-bot-policy-${random_string.random.result}"
  description = "Provides permissions to access bot secrets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:ListSecrets"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = "arn:aws:secretsmanager:us-east-2:545009864443:secret:*bot*"
      }
    ]
  })
}

resource "random_string" "random" {
  length  = 5
  special = false
}

resource "aws_iam_role" "reddit-bot-role" {
  name = "reddit-bot-role-${random_string.random.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach-role-and-policy" {
  depends_on = [aws_iam_role.reddit-bot-role, aws_iam_policy.reddit-bot-policy]
  role       = aws_iam_role.reddit-bot-role.name
  policy_arn = aws_iam_policy.reddit-bot-policy.arn
}

resource "aws_iam_instance_profile" "reddit-bot-instance-profile" {
  depends_on = [aws_iam_role.reddit-bot-role]
  name       = "reddit-bot-instance-profile-${random_string.random.result}"
  role       = aws_iam_role.reddit-bot-role.name
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

resource "aws_instance" "reddit-bot" {
  ami                  = data.aws_ami.amazon-linux-2.id
  instance_type        = "t4g.nano"
  key_name             = "michaels-personal-aws-kp"
  iam_instance_profile = aws_iam_instance_profile.reddit-bot-instance-profile.name
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    Name = "reddit-bot"
  }
  user_data = file("${path.module}/bootstrap.sh")
}
