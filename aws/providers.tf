terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.63.0"
    }

    random = {
      source  = "random"
      version = "3.1.0"
    }

    local = {
      source  = "local"
      version = "2.1.0"
    }
  }
}