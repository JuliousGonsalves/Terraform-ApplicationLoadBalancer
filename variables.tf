variable "project_vpc_cidr" {

  default = "172.24.0.0/16"
}


variable "region" {
  default = "ap-south-1"
}

variable "type" {

  default = "t2.micro"
}

variable "ami" {

  default = "ami-03fa4afc89e4a8a09"
}


variable "app" {
    
  default = "uber"
}

variable "project_env" {
    
  default = "test"
}
