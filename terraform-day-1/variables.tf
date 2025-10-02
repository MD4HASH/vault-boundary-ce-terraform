
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_1" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_1" {
  type    = string
  default = "10.0.2.0/24"
}

variable "instance_size" {
  type    = string
  default = "t3.medium"
}

variable "boundary_username" {
  type    = string
  default = "dev-admin"
}
