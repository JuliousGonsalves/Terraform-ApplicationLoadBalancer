module "vpc" {
    
  source   = "/var/terraform/modules/vpc/"
  vpc_cidr = var.project_vpc_cidr
  project  = var.app
  env      = var.project_env
  
}


resource "aws_launch_configuration" "lc" {

  name_prefix       = "${var.app}-"
  image_id          = var.ami
  instance_type     = var.type
  security_groups   = [ aws_security_group.webserver.id ]
  user_data         = file("setup.sh")
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {

  name_prefix             = "${var.app}-"
  launch_configuration    = aws_launch_configuration.lc.id
  health_check_type       = "EC2"
  min_size                = "2"
  max_size                = "2"
  desired_capacity        = "2"
  vpc_zone_identifier = [module.vpc.subnet_public1_id, module.vpc.subnet_public2_id]

  target_group_arns       = [aws_lb_target_group.tg.arn]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "${var.app}"
  }
  
  tag {
    key = "project"
    propagate_at_launch = true
    value = "${var.app}"
  }
    
    
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb_target_group" "tg" {


  name_prefix                   = "uber"
  port                          = 80
  protocol                      = "HTTP"
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay          = 5
  vpc_id                        = module.vpc.vpc_id
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200

  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_lb" "alb" {
  name_prefix                   = "uber"
  internal                      = false
  load_balancer_type            = "application"
  security_groups   = [ aws_security_group.webserver.id ]
  subnets                       = [module.vpc.subnet_public1_id, module.vpc.subnet_public2_id]
  enable_deletion_protection    = false
  depends_on                    = [ aws_lb_target_group.tg ]
  tags = {
     Name = "${var.app}"
   }
}

resource "aws_lb_listener" "listner" {

  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = " "
      status_code  = "500"
   }
  }

  depends_on = [  aws_lb.alb ]
}

resource "aws_lb_listener_rule" "main" {

  listener_arn = aws_lb_listener.listner.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  condition {
    host_header {
      values = ["app.juliousgonsalves94.tk"]
    }
  }
}
