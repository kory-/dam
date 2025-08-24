# Workflows for orchestrating the pipeline
resource "google_workflows_workflow" "dam_pipeline" {
  name            = "dam-daily-pipeline"
  region          = var.region
  description     = "Daily pipeline for processing CloudFront logs and detecting bots"
  service_account = google_service_account.workflows_sa.id
  
  # source_contents = file("${path.module}/../workflows/daily_pipeline.yaml")

  source_contents = templatefile(
    "${path.module}/../workflows/daily_pipeline.tftpl",
    {
      project_id         = var.project_id
      region             = var.region
      dataset_id         = var.dataset_id
      gcs_logs_bucket    = var.gcs_logs_bucket
      dataform_repository = "dam-dataform-repo"
      dataform_workspace = "production"
    }
  )

  depends_on = [
    google_project_service.required_apis,
    google_service_account.workflows_sa
  ]
}