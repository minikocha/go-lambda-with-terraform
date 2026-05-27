locals {
  # NOTE: 個々のハッシュ値を計算したのちに、それらを結合したものからハッシュ値を計算することで全体のハッシュ値を算出する
  source_files = [for file in fileset("${path.module}/src", "**") : file if length(regexall(".*\\.(go|sum|mod)$", file)) != 0]
  hash         = sha256(join("", [for file in local.source_files : filesha256(join("", ["${path.module}/src/", file]))]))
}

resource "terraform_data" "this" {
  # NOTE: ハッシュ値に変更があった時のみビルドとZip化を行う
  triggers_replace = [local.hash, ]

  provisioner "local-exec" {
    command = "go build -mod=readonly -ldflags='-s' -o ../bin/bootstrap ."
    environment = {
      CGO_ENABLED = "0"
      GOARCH      = "amd64"
      GOFLAGS     = "-trimpath"
      GOOS        = "linux"
    }
    working_dir = "${path.module}/src"
  }

  # NOTE: `archive_file`だと常にビルドしたバイナリファイルがローカルにあることを求められるため、こちらでZip化する
  provisioner "local-exec" {
    command     = "zip ./bootstrap.zip ./bootstrap"
    working_dir = "${path.module}/bin"
  }
}

resource "aws_s3_bucket" "this" {
  bucket_prefix = "go-lambda-with-terraform"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "this" {
  depends_on = [terraform_data.this, ]

  bucket = aws_s3_bucket.this.id
  key    = "bootstrap.zip"
  source = "${path.module}/bin/bootstrap.zip"

  lifecycle {
    # NOTE: `etag = filemd5("...")`だと常にビルドしたバイナリファイルがローカルにあることを求められるため、`replace_triggered_by`で代用する
    replace_triggered_by = [terraform_data.this, ]
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Effect" : "Allow"
        "Principal" : { "Service" = "lambda.amazonaws.com" }
        "Action" : "sts:AssumeRole"
      },
    ]
  })
  name = "go-lambda-with-terraform"
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.this.name
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/lambda/go-lambda-with-terraform"
}

resource "aws_lambda_function" "this" {
  function_name = "go-lambda-with-terraform"
  handler       = "bootstrap"
  role          = aws_iam_role.this.arn
  runtime       = "provided.al2023"
  s3_bucket     = aws_s3_bucket.this.id
  s3_key        = aws_s3_object.this.key

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  lifecycle {
    # NOTE: `source_code_hash = filesha256("...")`だと常にビルドしたバイナリファイルがローカルにあることを求められるため、`replace_triggered_by`で代用する
    replace_triggered_by = [terraform_data.this, ]
  }
}
