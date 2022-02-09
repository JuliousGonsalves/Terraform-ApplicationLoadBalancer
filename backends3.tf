terraform {
  backend "s3" {
    bucket = "s3-backend-project"
    key    = "s3-backend-project/project"
    region = "ap-south-1"
  }
}
