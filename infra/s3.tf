
# Referência aos buckets existentes
data "aws_s3_bucket" "data" {
  bucket = var.s3_data_bucket
}

# SNS Topic - centraliza eventos do bucket
resource "aws_sns_topic" "s3_events" {
  name = "${var.project_name}-s3-events"
}

# Permitir que o S3 publique mensagens no SNS
resource "aws_sns_topic_policy" "s3_publish" {
  arn = aws_sns_topic.s3_events.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3Publish",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.s3_events.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = data.aws_s3_bucket.data.arn
          }
        }
      }
    ]
  })
}

# Notificação do S3 → SNS (evento de criação/modificação)
resource "aws_s3_bucket_notification" "s3_to_sns" {
  bucket = data.aws_s3_bucket.data.id

  topic {
    topic_arn     = aws_sns_topic.s3_events.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".csv"
  }

  depends_on = [aws_sns_topic_policy.s3_publish]
}

# Assinatura da Lambda no tópico SNS
resource "aws_sns_topic_subscription" "sns_to_lambda" {
  topic_arn = aws_sns_topic.s3_events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.trainer.arn
}

# Permissão para SNS invocar a Lambda
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trainer.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.s3_events.arn
}


# Referência ao bucket de artefatos (onde está models/latest/model.joblib)
data "aws_s3_bucket" "artifacts" {
  bucket = var.s3_artifacts_bucket
}
