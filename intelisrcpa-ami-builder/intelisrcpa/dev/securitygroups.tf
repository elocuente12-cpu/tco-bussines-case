##############################################
# Security Group - Image Builder Build Instance
##############################################

resource "aws_security_group" "imagebuilder" {
  name        = "${local.naming_construct}-imagebuilder-sg"
  description = "Security group for EC2 Image Builder build instances"
  vpc_id      = data.aws_subnets.private.id

  # Egress: Allow all outbound (for Windows Update, S3, SSM, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.naming_construct}-imagebuilder-sg"
  }
}
