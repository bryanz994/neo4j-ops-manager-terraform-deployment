# resources will be created on AWS
terraform {
  required_providers {
    pkcs12 = {
      source = "chilicat/pkcs12"
      version = "0.1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.33.0"
    }
  }
}

provider "aws" {
  shared_credentials_files = ["./keys/creds"]
  region = var.region
}

provider "pkcs12" {
  # Configuration options
}