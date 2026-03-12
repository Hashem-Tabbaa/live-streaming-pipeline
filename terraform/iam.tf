# IAM roles for Media services

resource "aws_iam_role" "medialive_role" {
  name = "${var.project_name}-medialive-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "medialive.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "medialive_policy" {
  name = "${var.project_name}-medialive-policy"
  role = aws_iam_role.medialive_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mediaconnect:ManagedDescribeFlow",
          "mediaconnect:ManagedAddOutput",
          "mediaconnect:ManagedRemoveOutput",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "mediapackage:DescribeChannel",
          "mediapackagev2:*",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSecurityGroups",
        ]
        Resource = "*"
      }
    ]
  })
}

# Role for MediaConnect service

resource "aws_iam_role" "mediaconnect_role" {
  name = "${var.project_name}-mediaconnect-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "mediaconnect.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
