# alb.tf

resource "aws_lb" "jira_alb" {
  name               = "jira-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "jira-alb"
  }
}

resource "aws_lb_target_group" "jira_tg" {
  name     = "jira-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.jira_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "jira-target-group"
  }
}

resource "aws_lb_listener" "jira_listener" {
  load_balancer_arn = aws_lb.jira_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jira_tg.arn
  }
}
