variable "master_username" {
  type    = string
  default = "admin"
}

variable "master_password" {
  type      = string
  sensitive = true
}