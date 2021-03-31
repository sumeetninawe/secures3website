// Provider Config
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

// Website Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "examplewebsite1234.com"
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket_object" "index" {
  bucket = "examplewebsite1234.com"
  key    = "index.html"
  source = "./index.html"
  acl    = "public-read"
  content_type = "text/html"

  depends_on = [
    aws_s3_bucket.bucket
  ]

}

resource "aws_s3_bucket_object" "error" {
  bucket = "examplewebsite1234.com"
  key    = "error.html"
  source = "./error.html"
  acl    = "public-read"
  content_type = "text/html"

  depends_on = [
    aws_s3_bucket.bucket
  ]

}


// DNS Records
resource "aws_route53_zone" "main" {
  name = "examplewebsite1234.com"
}

resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "examplewebsite1234.com"
  type    = "A"
  alias {
    name                   = aws_s3_bucket.bucket.website_endpoint
    zone_id                = aws_s3_bucket.bucket.hosted_zone_id
    evaluate_target_health = false
  }
}