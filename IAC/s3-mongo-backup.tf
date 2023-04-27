resource "aws_s3_bucket" "backup" {
  bucket        = "project-backup-${random_string.suffix.result}"
  force_destroy = true
}


resource "aws_s3_bucket_ownership_controls" "myownership" {
  bucket = aws_s3_bucket.backup.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "myaccessblock" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "myacl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.myownership,
    aws_s3_bucket_public_access_block.myaccessblock,
  ]

  bucket = aws_s3_bucket.backup.id
  acl    = "public-read"
}

resource "aws_s3_bucket_versioning" "myversion" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}
