resource "aws_s3_bucket" "web" {
  count         = var.create_web_hosting ? 1 : 0
  bucket        = "${var.name_prefix}-web-${local.account_id}"
  force_destroy = true # content is build output, always reproducible
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "web" {
  count                   = var.create_web_hosting ? 1 : 0
  bucket                  = aws_s3_bucket.web[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  count  = var.create_web_hosting ? 1 : 0
  bucket = aws_s3_bucket.web[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "web" {
  count                             = var.create_web_hosting ? 1 : 0
  name                              = "${var.name_prefix}-web"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "web" {
  count               = var.create_web_hosting ? 1 : 0
  enabled             = true
  comment             = "${var.name_prefix} web"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2and3"

  origin {
    origin_id                = "s3"
    domain_name              = aws_s3_bucket.web[0].bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.web[0].id
  }

  default_cache_behavior {
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    response_headers_policy_id = aws_cloudfront_response_headers_policy.web[0].id
  }

  # SPA routing. With OAC and no s3:ListBucket, missing keys come back as 403, not 404.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = local.web_cert_arn == null ? [] : [local.web_domain]

  viewer_certificate {
    cloudfront_default_certificate = local.web_cert_arn == null
    acm_certificate_arn            = local.web_cert_arn
    ssl_support_method             = local.web_cert_arn == null ? null : "sni-only"
    minimum_protocol_version       = local.web_cert_arn == null ? "TLSv1" : "TLSv1.2_2021"
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_policy" "web" {
  count  = var.create_web_hosting ? 1 : 0
  bucket = aws_s3_bucket.web[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.web[0].arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.web[0].arn } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.web]
}

# Security headers, plus a Content-Security-Policy built from the only origins the SPA talks to:
# itself, the API and the Cognito domain. Tokens live in localStorage, so CSP is the main guard
# against an injected script reading them.
locals {
  # Built from inputs, not from resource attributes: the API's CORS origins and the pool client's
  # callback URLs both depend on the distribution, so reading them back here would be a cycle.
  csp_cognito_host = local.create_pool ? "${coalesce(var.cognito_domain_prefix, "${var.name_prefix}-${local.account_id}")}.auth.${local.region}.amazoncognito.com" : var.existing_cognito_domain
  csp_cognito = local.csp_cognito_host == null ? "" : (
    startswith(local.csp_cognito_host, "https://") ? local.csp_cognito_host : "https://${local.csp_cognito_host}"
  )
  # ponytail: any API Gateway in this region; the exact endpoint would need the API to exist first
  # (cycle above). Serving /v1 through CloudFront would make this 'self'.
  csp_api = "https://*.execute-api.${local.region}.amazonaws.com"
  csp = join("; ", [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self' ${local.csp_api} ${local.csp_cognito}",
    "form-action 'self' ${local.csp_cognito}",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "object-src 'none'",
  ])
}

resource "aws_cloudfront_response_headers_policy" "web" {
  count   = var.create_web_hosting ? 1 : 0
  name    = "${var.name_prefix}-web-security"
  comment = "HSTS, CSP, nosniff, no framing"

  security_headers_config {
    content_security_policy {
      content_security_policy = local.csp
      override                = true
    }
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }
    content_type_options { override = true }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# Runtime config the SPA fetches at startup, so one build works for every deployment.
resource "aws_s3_object" "config" {
  count         = var.create_web_hosting ? 1 : 0
  bucket        = aws_s3_bucket.web[0].id
  key           = "config.json"
  content_type  = "application/json"
  cache_control = "no-cache"
  content = jsonencode({
    apiUrl        = aws_apigatewayv2_api.this.api_endpoint
    region        = local.pool_region
    userPoolId    = local.user_pool_id
    clientId      = local.client_ids[0]
    cognitoDomain = local.cognito_domain
  })
}

# ---------- Optional custom domain (web_domain) ----------
# Route 53 (route53_zone_id set): validation + alias records are created here, one apply.
# Any other DNS host: apply once, create the web_dns_records output at the host, and apply again
# when the certificate shows ISSUED; only then does CloudFront switch to the domain.
locals {
  web_domain      = var.create_web_hosting ? var.web_domain : null
  web_dns_managed = local.web_domain != null && var.route53_zone_id != null
  web_cert_arn = local.web_dns_managed ? one(aws_acm_certificate_validation.web[*].certificate_arn) : one([
    for c in aws_acm_certificate.web : c.arn if c.status == "ISSUED"
  ])
}

resource "aws_acm_certificate" "web" {
  count             = local.web_domain == null ? 0 : 1
  domain_name       = local.web_domain
  validation_method = "DNS"
  tags              = local.common_tags

  lifecycle {
    create_before_destroy = true
    # ponytail: CloudFront only takes us-east-1 certificates; a provider alias would lift this.
    precondition {
      condition     = local.region == "us-east-1"
      error_message = "web_domain needs the stack in us-east-1 (CloudFront certificates must be issued there)."
    }
  }
}

resource "aws_route53_record" "web_validation" {
  for_each = {
    for o in flatten(aws_acm_certificate.web[*].domain_validation_options) : o.domain_name => o if local.web_dns_managed
  }
  zone_id         = var.route53_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "web" {
  count                   = local.web_dns_managed ? 1 : 0
  certificate_arn         = aws_acm_certificate.web[0].arn
  validation_record_fqdns = [for r in aws_route53_record.web_validation : r.fqdn]
}

resource "aws_route53_record" "web" {
  for_each = local.web_dns_managed ? toset(["A", "AAAA"]) : toset([])
  zone_id  = var.route53_zone_id
  name     = local.web_domain
  type     = each.key
  alias {
    name                   = aws_cloudfront_distribution.web[0].domain_name
    zone_id                = aws_cloudfront_distribution.web[0].hosted_zone_id
    evaluate_target_health = false
  }
}
