locals{
  region = "us-east-1"
  account = var.account  # Updated to a valid 12-digit AWS account ID
}
provider "aws" {
  region     = local.region
  skip_credentials_validation = true
  skip_metadata_api_check = true
  skip_requesting_account_id = true

  endpoints {
    lambda     = "http://localhost:4566"
    apigateway = "http://localhost:4566"
    iam        = "http://localhost:4566"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "archive_file" "employee_lambda" {
  type        = "zip"
  source_dir  = "./lambda/employee"
  output_path = "employee.zip"
}

resource "aws_lambda_function" "example" {
  function_name = "example_lambda"
  handler       = "app.lambda_handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec.arn

  filename         = "employee.zip"
  source_code_hash = data.archive_file.employee_lambda.output_base64sha256

  environment {
    variables = {
      greeting = "Hello"
    }
  }
}

resource "aws_api_gateway_rest_api" "example" {
  name        = "example_api"
  description = "Example API"
}

resource "aws_api_gateway_resource" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "example"
}

resource "aws_api_gateway_method" "example" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.example.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "example" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.example.id
  http_method             = aws_api_gateway_method.example.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  passthrough_behavior = "WHEN_NO_MATCH"
  cache_key_parameters = ["method.request.path.param"]
 uri = "arn:aws:apigateway:${local.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.example.arn}/invocations"
}

resource "aws_api_gateway_deployment" "example" {
  depends_on = [aws_api_gateway_integration.example]
  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name  = "dev"
}

resource "aws_lambda_permission" "example" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn  = "arn:aws:execute-api:${local.region}:${local.account}:${aws_api_gateway_rest_api.example.id}/*/${aws_api_gateway_method.example.http_method}${aws_api_gateway_resource.example.path}"
}

output "api_gateway_invoke_url" {
  # value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.example.id}/${aws_api_gateway_deployment.example.stage_name}/${aws_api_gateway_resource.example.path}"
  value =  "https://${aws_api_gateway_rest_api.example.id}.execute-api.localhost.localstack.cloud:4566/${aws_api_gateway_deployment.example.stage_name}${aws_api_gateway_resource.example.path}"
}
output "apigatewaylocalhost_url"{
  value="http://localhost:4566/_aws/execute-api/${aws_api_gateway_rest_api.example.id}/${aws_api_gateway_deployment.example.stage_name}${aws_api_gateway_resource.example.path}"
}