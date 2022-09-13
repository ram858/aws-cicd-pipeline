variable "dockerhub_credentials"{
    type = string
}

variable "codestar_connector_credentials" {
    type = string
}
variable "dynamodb_table" {
  description = "name of the ddb table"
  type = string
  default = "MyBook"
  
}

variable "lambda_name" {
  description = "name of the lambda function"
  type = string
  default = "api-lambda-dynamo"
  
}

variable "api_name" {
  description = "name of the lambda function"
  type = string
  default = "apigw-REST-lambda"

}

variable "lambda_log_retention" {
  description = "lambda log retention in days"
  type = number
  default = 7
}

variable "apigw_log_retention" {
  description = "api gwy log retention in days"
  type = number
  default = 7

}

variable "s3_bucket_prefix" {
  description = "S3 bucket prefix"
  type = string
  default = "apigw-lambda-ddb"
  
}

# variable "path_parts" {
#     description = "insert the path parts for your API"
#     type = list 
# }

variable "http_methods" {
  description = " insert  the http methods for the api-gateway "
  type = list
  default = ["GET","POST", "PUT"]

}

variable "stage_name" {
    description = "insert the name of stage for deployment"
    type = string
    default = "test"  
}


variable "stage_description" {
  description = "insert the desccription about the stage"
  type = string
  default = "this is the test stage of API"
}

variable "metric_name" {
    description = "insert the cloud-watch metrics that you want to monitor"
    type = list(any)
    default = ["4XXError", "5XXError"]
}

variable "integration_http_methods" {
    description = "insert the HTTP methods for the integration"
    type = list
    default = ["POST"]
  
}
variable "deployment_enabled" {
    description = "insert if you want to enable or disable deployment"
    type = bool
    default = true
  
}