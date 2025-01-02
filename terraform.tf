terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.23.1"
    }
  }

  required_version = "~> 1.2"

  backend "s3" {
    bucket = "terraforms-buckets"
    key    = "states-veiculovenda"
    region = "us-east-2"
  }
}