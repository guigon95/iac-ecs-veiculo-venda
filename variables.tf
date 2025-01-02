variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-2"
}

variable "account_id" {
  type    = string
}

variable "access_key" {
  type    = string
}

variable "secret_key" {
  type    = string
}

variable "desired_capacity" {
  description = "desired number of running nodes"
  default     = 1
}

variable "container_port" {
  default = "8080"
}

variable "image_url" {
  type    = string
}

variable "memory" {
  default = "512"
}

variable "cpu" {
  default = "256"
}

variable "cluster_name" {
  type    = string
}

variable "cluster_task" {
  type    = string
}
variable "cluster_service" {
  type    = string
}