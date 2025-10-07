terraform {
  backend "s3" {
    bucket         = "thagmrs-artifacts"
    key            = "terraform/state.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
