##############################################
# IAM - Image Builder Instance Profile
##############################################

resource "aws_iam_role" "imagebuilder" {
  name = "${local.naming_construct}-imagebuilder-role"

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

  tags = {
    Name = "${local.naming_construct}-imagebuilder-role"
  }
}

resource "aws_iam_role_policy_attachment" "imagebuilder_ssm" {
  role       = aws_iam_role.imagebuilder.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "imagebuilder_ec2" {
  role       = aws_iam_role.imagebuilder.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "imagebuilder_s3" {
  role       = aws_iam_role.imagebuilder.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "imagebuilder" {
  name = "${local.naming_construct}-imagebuilder-profile"
  role = aws_iam_role.imagebuilder.name

  tags = {
    Name = "${local.naming_construct}-imagebuilder-profile"
  }
}
