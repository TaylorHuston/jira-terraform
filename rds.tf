resource "aws_db_subnet_group" "jira_db_subnet_group" {
  name       = "jira-db-subnet"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "jira-db-subnet-group"
  }
}

resource "aws_db_instance" "jira_db" {
  identifier     = "jira-database"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "jiradb"
  username = "jiraadmin"
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.jira_db_subnet_group.name

  skip_final_snapshot = true # For testing only!

  tags = {
    Name = "jira-database"
  }
}

# Generate a random password
resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Random ID for unique naming
resource "random_id" "deployment" {
  byte_length = 4
}
