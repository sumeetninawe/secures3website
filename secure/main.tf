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

// Key for encryption
resource "aws_kms_key" "a" {
  description             = "KMS key"
  deletion_window_in_days = 10
}

// Website Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "examplewebsite1234.com"
  acl    = "private"
  policy = <<-POLICY
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Sid": "MainBucketPermissions",
        "Effect": "Allow",
        "Principal": "*",
        "Action": ["s3:GetObject"],
        "Resource": ["arn:aws:s3:::examplewebsite1234.com/*"]
      }]
    }
    POLICY

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  versioning {
    enabled = true
  }

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "log/"
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.a.arn
        sse_algorithm     = "aws:kms"
      }
    }
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

// Log bucket
resource "aws_s3_bucket" "log_bucket" {
  bucket = "websitelogs1234"
  acl    = "log-delivery-write"
  policy = <<-POLICY
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Sid": "MainBucketPermissions",
        "Effect": "Deny",
        "Principal": "*",
        "Action": ["s3:GetObject"],
        "Resource": ["arn:aws:s3:::websitelogs1234/*"]
      }]
    }
    POLICY

    server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.a.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
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
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

// CloudFront distribution
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "S3OriginConfig"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.log_bucket.bucket_domain_name
    prefix          = "cloudfrontlogs"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3OriginConfig"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}