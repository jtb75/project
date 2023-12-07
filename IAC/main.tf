provider "aws" {
  region = var.region
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

