resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "BookTable"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "BookId"
  range_key      = "Author"

  attribute {
    name = "BookId"
    type = "S"
  }

  attribute {
    name = "Author"
    type = "S"
  }
}



// Lambda set-up /////
resource "aws_s3_bucket" "lambda_bucket" {
  bucket_prefix = var.s3_bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_acl" "private_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "lambda_zip" {
  type = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_s3_object" "this" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "src.zip"
  source = data.archive_file.lambda_zip.output_path

  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

// defining lambda function
resource "aws_lambda_function" "apigw_lambda_ddb" {
  function_name = var.lambda_name
  description = "apigw interaction with lambda and dynamodb"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.this.key

  runtime = "nodejs16.x"
  handler = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
  
  environment {
    variables = {
      DDB_TABLE = var.dynamodb_table
    }
  }
  depends_on = [aws_cloudwatch_log_group.lambda_logs]
  
}
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name = "/aws/lambda/${var.lambda_name}"

  retention_in_days = var.lambda_log_retention
}


resource "aws_iam_role" "lambda_exec" {
  name = "LambdaDdbPost"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_exec_role" {
  name = "lambda-tf-pattern-ddb-post"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/${var.dynamodb_table}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_exec_role.arn
}
//APIGW defination
resource "aws_api_gateway_rest_api" "example" {
  name = "aws_api_dynamodb"
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "example"
      version = "1.0"
    }
    paths = {
      "/items" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            type                 = "AWS_PROXY"
            uri                  = aws_lambda_function.apigw_lambda_ddb.invoke_arn
          }
        }
      },
      "/item" = {
        post = {
          x-amazon-apigateway-integration = {
            httpMethod           = "POST"
            type                 = "AWS_PROXY"
            uri                  = aws_lambda_function.apigw_lambda_ddb.invoke_arn
          }
        },
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            type                 = "AWS_PROXY"
            uri                  = aws_lambda_function.apigw_lambda_ddb.invoke_arn
          }
        }
      },
  }
})
}
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${var.api_name}"

  retention_in_days = var.apigw_log_retention
}
//


resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.apigw_lambda_ddb.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.example.execution_arn}/*/*"
}

resource "aws_cloudwatch_metric_alarm" "APIgateway" {
  count = length(var.metric_name) > 0 ? length(var.metric_name) : 0
  alarm_name                = "APIgateway-alarm-test"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = element(var.metric_name, count.index)
  namespace                 = "AWS/ApiGateway"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors 4xx and 5xx errors on apigateway"
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "test"
}