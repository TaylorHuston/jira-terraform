# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "jira-alb-sg"
  description = "Security group for Jira ALB"
  vpc_id      = aws_vpc.jira_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jira-alb-sg"
  }
}

# Security group for Jira EC2 instance
resource "aws_security_group" "jira_sg" {
  name        = "jira-ec2-sg"
  description = "Security group for Jira server"
  vpc_id      = aws_vpc.jira_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Only from ALB!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Can reach anywhere
  }

  tags = {
    Name = "jira-ec2-sg"
  }
}

# Security group for Jira RDS instance
resource "aws_security_group" "rds_sg" {
  name        = "jira-rds-sg"
  description = "Security group for Jira RDS database"
  vpc_id      = aws_vpc.jira_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.jira_sg.id] # Only from Jira server
  }

  # Notice: No egress rules needed for RDS!

  tags = {
    Name = "jira-rds-sg"
  }
}
