# Service Account for Workflows execution
resource "google_service_account" "workflows_sa" {
  account_id   = "dam-workflows-sa"
  display_name = "DAM Workflows Service Account"
  description  = "Service account for executing DAM data pipeline workflows"
}

# Service Account for Dataflow jobs
resource "google_service_account" "dataflow_sa" {
  account_id   = "dam-dataflow-sa"
  display_name = "DAM Dataflow Service Account"
  description  = "Service account for running Dataflow jobs"
}

# IAM roles for Workflows SA
resource "google_project_iam_member" "workflows_sa_roles" {
  for_each = toset([
    "roles/workflows.invoker",
    "roles/dataflow.developer",
    "roles/bigquery.jobUser",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/iam.serviceAccountUser"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# IAM roles for Dataflow SA
resource "google_project_iam_member" "dataflow_sa_roles" {
  for_each = toset([
    "roles/dataflow.worker",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/storage.objectAdmin",
    "roles/compute.viewer",
    "roles/logging.logWriter"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# BigQuery dataset-level permissions for Workflows SA
resource "google_bigquery_dataset_iam_member" "workflows_dataset_editor" {
  dataset_id = var.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# Storage bucket permissions for reading logs
resource "google_storage_bucket_iam_member" "workflows_logs_viewer" {
  bucket = var.gcs_logs_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.workflows_sa.email}"
}

resource "google_storage_bucket_iam_member" "dataflow_logs_viewer" {
  bucket = var.gcs_logs_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Create temp bucket for Dataflow (import if exists)
resource "google_storage_bucket" "dataflow_temp" {
  name          = "dam-dataflow-temp"
  location      = var.region
  force_destroy = false
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}

# Permissions for Dataflow temp bucket
resource "google_storage_bucket_iam_member" "dataflow_temp_admin" {
  bucket = google_storage_bucket.dataflow_temp.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

resource "google_storage_bucket_iam_member" "workflows_temp_admin" {
  bucket = google_storage_bucket.dataflow_temp.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.workflows_sa.email}"
}