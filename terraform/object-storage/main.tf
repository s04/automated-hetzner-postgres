# Optional, independent state: a server destroy must not remove recovery storage.
terraform {
  required_version = ">= 1.5"
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.43.0"
    }
  }
}

provider "minio" {
  # Credentials are read from MINIO_USER / MINIO_PASSWORD (mapped by make bucket).
  minio_server   = var.s3_endpoint
  minio_region   = var.s3_region
  minio_ssl      = true
  s3_compat_mode = true
}

resource "minio_s3_bucket" "backups" {
  bucket         = var.bucket_name
  bucket_prefix  = var.bucket_name == null ? "postgres-backups-" : null
  acl            = "private"
  object_locking = false
  force_destroy  = false
}

output "bucket_name" {
  description = "Name of the private backup bucket."
  value       = minio_s3_bucket.backups.bucket
}

output "backup_config" {
  description = "Non-secret Ansible settings; make bucket saves these to backup.generated.yml."
  value = yamlencode({
    postgres_s3_backup_enabled = true
    postgres_s3_bucket         = minio_s3_bucket.backups.bucket
    postgres_s3_endpoint       = split(":", var.s3_endpoint)[0]
    postgres_s3_port           = try(tonumber(split(":", var.s3_endpoint)[1]), 443)
    postgres_s3_region         = var.s3_region
    postgres_s3_prefix         = var.backup_prefix
  })
}
