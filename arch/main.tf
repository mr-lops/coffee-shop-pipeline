# Configure what Terraform needs to start
terraform {

  # Define the Terraform version to be used
  required_version = "~> 1.6.0"

  # Define the providers that will be used
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  # Uncomment the following block to use the local backend
  # backend "local" {
  #   path = "terraform_state/terraform.tfstate"
  # }

  # Configure the S3 backend
  backend "s3" {
    bucket = "my-terraform-bucket"
    key    = "project-aws/terraform.tfstate"
    region = "us-east-1"
  }
}

# Configuring the AWS provider in Terraform
provider "aws" {
  shared_config_files = var.credentials.credentials_file # where it will fetch the credentials
  region              = var.credentials.region

  # These tags will be added to any resource that is created
  default_tags {
    tags = {
      managed-by  = "terraform"
      environment = "dev"
      team        = "data"
      project     = "ingest-data-aws"
    }
  }
}
