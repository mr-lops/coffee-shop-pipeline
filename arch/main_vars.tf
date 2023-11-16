variable "credentials" {
  type = object({
    credentials_file = string
    region           = string
    profile          = string
  })
  sensitive = true
  default = {
    credentials_file = "~/.aws/credentials"
    region           = "us-east-1"
    profile          = "vitor"
  }
}

variable "bucket_terraform" {
  description = "informações do bucket que armazena os dado gerados pelo terraform"
  type = object({
    bucket-name = string
    region      = string
  })

  sensitive = true
  default = {
    bucket-name = "bucket-terraform-lops"
    region      = "us-east-1"

  }
}