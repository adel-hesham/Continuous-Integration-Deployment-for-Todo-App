terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.21.0"

    }
  }
}

terraform {
  backend "s3" {
    bucket = "solar-app-s3"
    key = "todo-app-state/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}