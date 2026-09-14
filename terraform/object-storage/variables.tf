variable "bucket_name" {
  description = "Optional globally unique bucket name; null generates a postgres-backups-* name."
  type        = string
  default     = null
  validation {
    condition     = var.bucket_name == null ? true : can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Use a valid S3 bucket name: 3–63 lowercase letters, digits, dots, or hyphens."
  }
}

variable "s3_endpoint" {
  description = "Hetzner S3 endpoint hostname without a scheme or path."
  type        = string
  default     = "fsn1.your-objectstorage.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+(:[0-9]+)?$", var.s3_endpoint))
    error_message = "Use a hostname with optional port, not a URL."
  }
}

variable "s3_region" {
  description = "S3 signing region; for Hetzner, match the endpoint location (fsn1, nbg1, or hel1)."
  type        = string
  default     = "fsn1"
}

variable "backup_prefix" {
  description = "Repository prefix, unique per independent database cluster."
  type        = string
  default     = "/postgres"
}
