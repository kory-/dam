variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Default region for resources"
  type        = string
}

variable "zone" {
  description = "Default zone for compute resources"
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID"
  type        = string
}

variable "gcs_logs_bucket" {
  description = "GCS bucket containing CloudFront logs"
  type        = string
}

variable "scheduler_timezone" {
  description = "Timezone for Cloud Scheduler"
  type        = string
  default     = "Asia/Tokyo"
}

variable "scheduler_cron" {
  description = "Cron schedule for daily pipeline"
  type        = string
  default     = "0 4 * * *"  # 4:00 JST daily
}

variable "dataflow_temp_location" {
  description = "GCS path for Dataflow temp files"
  type        = string
}

variable "dataflow_staging_location" {
  description = "GCS path for Dataflow staging files"
  type        = string
}

variable "notification_email" {
  description = "Email for error notifications (optional)"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub personal access token for Dataform repository access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dataform_git_repo_url" {
  description = "GitHub repository URL for the DAM project (e.g., https://github.com/username/dam.git)"
  type        = string
  default     = ""
}