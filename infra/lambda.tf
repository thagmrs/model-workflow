resource "aws_ecr_repository" "lambda_repo" {
  name = "${var.project_name}-lambda-repo"
}

resource "aws_lambda_function" "trainer" {
  function_name = "${var.project_name}-trainer"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"

  image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-2.amazonaws.com/${var.ecr_inference_repo}:latest"

  timeout = 900
  memory_size = 3008

  environment {
    variables = {
      ARTIFACTS_BUCKET = var.s3_artifacts_bucket
    }
  }
}
