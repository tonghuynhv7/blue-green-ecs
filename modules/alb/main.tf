locals {
  name = "${var.project}-${var.env}"
}

# ─── Security Group cho ALB ─────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Allow HTTP port 80 (production) and 81 (staging/tester)"
  vpc_id      = var.vpc_id

  # Port 80 — production traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 81 — tester truy cập Green cluster
  ingress {
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

# ─── Application Load Balancer ───────────────────────────────────────────────
resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.pub_subnet_ids

  enable_deletion_protection = false

  tags = { Name = "${local.name}-alb" }
}

# ─── Target Group Blue ───────────────────────────────────────────────────────
resource "aws_lb_target_group" "blue" {
  name        = "${local.name}-tg-blue"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate dùng ip, không dùng instance

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "${local.name}-tg-blue" }
}

# ─── Target Group Green ──────────────────────────────────────────────────────
resource "aws_lb_target_group" "green" {
  name        = "${local.name}-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "${local.name}-tg-green" }
}

# ─── Listener port 80 → Blue (production) ────────────────────────────────────
resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = { Name = "${local.name}-listener-80" }

  # lifecycle ignore_changes để Jenkinsfile/script switch traffic
  # mà Terraform không rollback khi apply lần sau
  lifecycle {
    ignore_changes = [default_action]
  }
}

# ─── Listener port 81 → Green (staging/tester) ───────────────────────────────
resource "aws_lb_listener" "staging" {
  load_balancer_arn = aws_lb.this.arn
  port              = 81
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  tags = { Name = "${local.name}-listener-81" }

  lifecycle {
    ignore_changes = [default_action]
  }
}
