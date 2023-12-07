provider "aws" {
  region = var.region
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

