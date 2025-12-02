# variable "ami" {
#   description = "AMI ID for EC2"
#   default     = "ami-0c02fb55956c7d316" # Ubuntu 22.04 (us-east-1)
# }


# variable "vpc_cidr" {
#   type = string  
# }
# variable "public_subnet_cidr" {
#   type = string  
# }
# variable "private_subnet_cidr" {
#   type = string  
# }

# variable "key_name" {
#   type=string
#   default = "id_rsa.pub"
# }

# variable "public_key" {
#   type=any
#   default = file("/home/adel/.shh/id_rsa.pub")
# }

locals {
  vpc_cidr_block = "10.0.0.0/16"
  region         = "us-east-1"
  AZ1            = "us-east-1a"
  AZ2            = "us-east-1b"
  eks_name       = "solar-system-application"
  eks_version    = "1.33"
}
