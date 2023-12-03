# configura oque o terraform precisa para iniciar
terraform {

  #Define versão do Terraform que irá ser utilizada
  required_version = "~> 1.6.0"

  # Define os providers que serão utilizados
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  #   backend "local" {
  #     path = "terraform_state/terraform.tfstate"
  #   }

  backend "s3" {
    bucket = "bucket-terraform-lops"
    key    = "project-aws/terraform.tfstate"
    region = "us-east-1"
  }
}

# Configurando o provider AWS no Terraform
provider "aws" {
  shared_config_files = var.credentials.credentials_file # onde que ele ira pegar as credenciais
  region              = var.credentials.region


  # Essas tags serão adicionadas para qualquer recurso que for criado
  default_tags {
    tags = {
      managed-by  = "terraform"
      environment = "dev"
      team        = "data"
      project     = "ingest-data-aws"
    }
  }
}
