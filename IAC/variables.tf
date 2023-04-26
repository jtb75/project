variable "access_key" {
  type = string
}
variable "secret_key" {
  type = string
}

variable "region" {
  default     = "us-east-1"
  description = "AWS region"
}

variable "admin_ip" {
  default = ["97.88.199.147/32", "10.0.0.0/15"]
}

variable "key_pair" {
  default     = "project"
  description = "Key pair to be used on ec2 instances"
}
