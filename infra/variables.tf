variable "aws_region" {
  type    = string
}

variable "project_name" {
  type    = string
}

variable "s3_data_bucket" {
  type = string
}

variable "s3_artifacts_bucket" {
  type = string
}

# caminho do artefato "mais recente"
variable "model_key_latest" {
  type    = string
}

variable "api_key" {
  type        = string
}


variable "vpc_cidr" {
  type    = string
}

variable "ecr_training_repo" {
  type    = string
}

variable "ecr_inference_repo" {
  type    = string
}