# Dataform configuration for the DAM pipeline

# Enable Dataform API
resource "google_project_service" "dataform_api" {
  service = "dataform.googleapis.com"
  
  disable_on_destroy = false
}

# Service Account for Dataform
resource "google_service_account" "dataform_sa" {
  account_id   = "dam-dataform-sa"
  display_name = "DAM Dataform Service Account"
  description  = "Service account for Dataform to execute BigQuery queries"
}

# IAM roles for Dataform SA
resource "google_project_iam_member" "dataform_sa_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/logging.logWriter"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.dataform_sa.email}"
}

# Allow Workflows SA to act as Dataform SA (this is the actAs permission)
resource "google_service_account_iam_member" "workflows_act_as_dataform" {
  service_account_id = google_service_account.dataform_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# Allow Workflows SA to use Dataform SA
resource "google_service_account_iam_member" "workflows_use_dataform" {
  service_account_id = google_service_account.dataform_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# Grant Workflows SA permission to invoke Dataform
resource "google_project_iam_member" "workflows_dataform_editor" {
  project = var.project_id
  role    = "roles/dataform.editor"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# Dataform Repository with Git integration
resource "google_dataform_repository" "dam_repo" {
  provider = google-beta
  name     = "dam-dataform-repo"
  project  = var.project_id
  region   = var.region
  
  service_account = google_service_account.dataform_sa.email
  
  # Git integration settings
  # NOTE: You need to set up the GitHub repository and provide the URL
  # Example: https://github.com/your-username/dam.git
  git_remote_settings {
    url                                 = var.dataform_git_repo_url
    default_branch                      = "main"
    authentication_token_secret_version = google_secret_manager_secret_version.github_token.id
  }
  
  workspace_compilation_overrides {
    default_database = var.project_id
    schema_suffix    = ""
    table_prefix     = ""
  }

  depends_on = [
    google_project_service.dataform_api,
    google_service_account.dataform_sa,
    google_secret_manager_secret_version.github_token
  ]
}

# Secret Manager for GitHub token
resource "google_secret_manager_secret" "github_token" {
  secret_id = "dataform-github-token"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

# Secret version - actual token will be set via gcloud or console
resource "google_secret_manager_secret_version" "github_token" {
  secret      = google_secret_manager_secret.github_token.id
  secret_data = var.github_token != "" ? var.github_token : "placeholder-token"
}

# Enable Secret Manager API
resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Grant Dataform access to the secret
resource "google_secret_manager_secret_iam_member" "dataform_secret_access" {
  secret_id = google_secret_manager_secret.github_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
  
  depends_on = [google_secret_manager_secret.github_token]
}

# Data source to get project number
data "google_project" "project" {
  project_id = var.project_id
}