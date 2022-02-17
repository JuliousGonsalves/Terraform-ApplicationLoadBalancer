# Terraform-ApplicationLoadBalancer

[![Builds](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

## Description.

Here we are going to call a custom vpc module and configure a application load balancer in it. The terraform state file will be stored in S3 bucket.

### prerequisite for this project

-Iam role with with attached policies for the creation of VPC. (By using role we can avoid adding access keys and secretkey in terraform files)

-Basic knowledge in AWS services such as VPC, ec2-instance, s3 bucket and bash script

### Used Languages
```sh
Terraform - IAC Tool

Bash script
```

#-----------------------------------------
### Cloning the vpc module 
#-----------------------------------------
```sh
# yum install git -y

# mkdir -p /var/terraform/modules/vpc/ 

# git clone git@github.com:JuliousGonsalves/terraform_vpc.git
```

#------------------------------------
### Declaring variables -variabled.tf
#-------------------------------------
```sh
variable "project_vpc_cidr" {

  default = "172.24.0.0/16"       # Adjust the cidr ip value as per your requirement
}


variable "region" {
  default = "ap-south-1"          # declare the aws region
}

variable "type" {

  default = "t2.micro"            # Instance type
}

variable "ami" {

  default = "ami-03fa4afc89e4a8a09"  # Provide AMI name (note ami id changes from region to region)
}


variable "app" {

  default = "uber"               # provide the project/app name
}

variable "project_env" {

  default = "test"              # decalre your enviroment(test/dev/prod)
}
```



#-----------------------------------------------
### Creating a provider.tf file
#---------------------------------------------
```sh
provider "aws" {
  region = var.region
}
```

#--------------------------------------------------------------------------
### configuring backend point s3 bucket to store terraform file - backends3.tf
#---------------------------------------------------------------------------

```sh
terraform {
  backend "s3" {
    bucket = "Bucket name"
    key    = "path to store the tf file"
    region = "region name"
  }
}
```

#----------------------------------------------------------------------
### Bash script for user data - setup.sh
#-----------------------------------------------------------------

- A simple bash script to install apache and to create a index.php file in document root. 
  The website will be loading the hostname of instances which will help to identify the alb working much easier

```sh
#!/bin/bash

yum install httpd php -y

cat <<EOF > /var/www/html/index.php
<?php
\$output = shell_exec('echo $HOSTNAME');
echo "<h1><center><pre>\$output</pre></center></h1>";
echo "<h1><center>Application by Julious Gonsalves</center></h1>"
?>
EOF

service httpd restart
chkconfig httpd on
```

#-------------------------------------------------------------------
### creating a security group for webserver instance - sg.tf
#-------------------------------------------------------------------
```sh
resource "aws_security_group" "webserver" {

  name        = "${var.app}-webserver-${var.project_env}"
  description = "allow 22, 80 and 443 traffic"
  vpc_id      = module.vpc.vpc_id


  ingress {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }


ingress {
    description      = ""
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

ingress {
    description      = ""
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.app}-webserver-${var.project_env}"
    project = var.app
     environment = var.project_env
  }
}
```

#----------------------------------------------------------------------------
### Creating main.tf
#-------------------------------------------------------------------------


## Calling the vpc module
```sh

module "vpc" {

  source   = "/var/terraform/modules/vpc/"
  vpc_cidr = var.project_vpc_cidr
  project  = var.app
  env      = var.project_env

}
```
## Lauch Configuration
```sh
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
```
## Auto scaling group
```sh
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
```
## Target group
```sh
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
```

## load balancer configuration
```sh
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
      values = ["app.juliousgonsalves94.tk"]   # provide your web site here
    }
  }
}
```

## Initialising terraform

terraform init

## Checking for syntax errors

terraform validate

## Planning  the architecture and verify once again

terraform plan

## Applying the architecture to AWS

terraform apply



### Conclusion

Here is a document to use a vpc module and create a application load balacer with 2 webserver instances. The ALB will work in a roud robin format and traffic will be split to both instance.
If one instance gets stopped , it will lauch a instance automatically.
















