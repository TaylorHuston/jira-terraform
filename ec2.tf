resource "aws_instance" "jira_server" {
  ami           = "ami-005fc0f236362e99f" # Ubuntu 22.04 LTS in us-east-1
  instance_type = "t3.medium"             # Jira needs decent resources

  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.jira_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.jira_profile.name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  # Updated user_data in ec2.tf for Jira 10.3 LTS

  user_data = templatefile("${path.module}/scripts/install_jira.sh", {
    db_endpoint = aws_db_instance.jira_db.endpoint
    db_password = random_password.db_password.result
    db_name     = aws_db_instance.jira_db.db_name
    db_username = aws_db_instance.jira_db.username
  })

  # Force instance replacement when user_data changes
  user_data_replace_on_change = true

  tags = {
    Name = "jira-server"
  }
}

resource "aws_lb_target_group_attachment" "jira_tg_attachment" {
  target_group_arn = aws_lb_target_group.jira_tg.arn
  target_id        = aws_instance.jira_server.id
  port             = 8080
}

# IAM role for EC2 to use Systems Manager
resource "aws_iam_role" "jira_role" {
  name = "jira-ec2-role"

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

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.jira_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jira_profile" {
  name = "jira-ec2-profile"
  role = aws_iam_role.jira_role.name
}
