variable "credentials" {
  type = object({
    credentials_file = list(string)
    region           = string
  })
  sensitive = true
  default = {
    credentials_file = ["~/.aws/credentials"]
    region           = "us-east-1"
  }
}

