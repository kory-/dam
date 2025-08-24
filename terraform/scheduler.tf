# Cloud Scheduler for daily pipeline execution
resource "google_cloud_scheduler_job" "dam_daily_trigger" {
  name        = "dam-daily-pipeline-trigger"
  description = "Trigger daily pipeline at 4:00 AM JST"
  region      = var.region
  
  schedule    = var.scheduler_cron
  time_zone   = var.scheduler_timezone
  
  retry_config {
    retry_count          = 3
    min_backoff_duration = "30s"
    max_backoff_duration = "300s"
    max_retry_duration   = "0s"
    max_doublings        = 2
  }
  
  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/workflows/${google_workflows_workflow.dam_pipeline.name}/executions"
    
    body = base64encode(jsonencode({
      argument = jsonencode({
        # Use default (today's date) which will be processed as yesterday in the workflow
      })
    }))
    
    headers = {
      "Content-Type" = "application/json"
    }
    
    oauth_token {
      service_account_email = google_service_account.workflows_sa.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
  
  depends_on = [
    google_workflows_workflow.dam_pipeline,
    google_project_service.required_apis
  ]
}

