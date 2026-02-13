# Backend configuration - use with -backend-config flag
# This allows different backend configurations for main and sandbox environments
terraform {
  cloud {}  # Configured via backend.conf files in main/ and sandbox/ folders
  
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
