# Upload transform.js to GCS
resource "google_storage_bucket_object" "transform_js" {
  name   = "scripts/transform.js"
  bucket = google_storage_bucket.dataflow_temp.name
  source = "${path.module}/../dataflow/transform.js"
}

# Upload schema JSON to GCS
resource "google_storage_bucket_object" "cf_logs_schema" {
  name   = "schemas/cf_logs_schema.json"
  bucket = google_storage_bucket.dataflow_temp.name
  source = "${path.module}/../dataflow/cf_logs_schema.json"
}