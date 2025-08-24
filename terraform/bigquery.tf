# BigQuery Dataset (import existing or create new)
resource "google_bigquery_dataset" "dam_dataset" {
  dataset_id                 = var.dataset_id
  location                   = var.region
  delete_contents_on_destroy = false
  
  description = "Dataset for DAM workflow - CloudFront logs analysis and bot detection"
  
  access {
    role          = "OWNER"
    user_by_email = google_service_account.workflows_sa.email
  }
  
  access {
    role          = "WRITER"
    user_by_email = google_service_account.dataflow_sa.email
  }
}

# cf_logs table (partitioned by date)
resource "google_bigquery_table" "cf_logs" {
  dataset_id          = google_bigquery_dataset.dam_dataset.dataset_id
  table_id            = "cf_logs"
  deletion_protection = false
  
  schema = file("${path.module}/../ddl/cf_logs.json")
}

# ip_features table (for storing aggregated features)
resource "google_bigquery_table" "ip_features" {
  dataset_id          = google_bigquery_dataset.dam_dataset.dataset_id
  table_id            = "ip_features"
  deletion_protection = false
  
  schema = file("${path.module}/../ddl/ip_features.json")
}

# bot_ips table (for storing prediction results)
resource "google_bigquery_table" "bot_ips" {
  dataset_id          = google_bigquery_dataset.dam_dataset.dataset_id
  table_id            = "bot_ips"
  deletion_protection = false
  
  schema = file("${path.module}/../ddl/bot_ips.json")
}

# cf_logs_staging table (temporary for deduplication)
resource "google_bigquery_table" "cf_logs_staging" {
  dataset_id          = google_bigquery_dataset.dam_dataset.dataset_id
  table_id            = "cf_logs_staging"
  deletion_protection = false

  schema = file("${path.module}/../ddl/cf_logs.json")

  # 日付パーティション（date列がDATE型）
  time_partitioning {
    type  = "DAY"
    field = "date"
  }

  # よく使うキーでクラスタリング（検索/重複排除コスト削減）
  clustering = ["c_ip", "cs_uri_stem", "x_edge_request_id"]
}

# cf_logs_filtered view
resource "google_bigquery_table" "cf_logs_filtered" {
  dataset_id          = google_bigquery_dataset.dam_dataset.dataset_id
  table_id            = "cf_logs_filtered"
  deletion_protection = false
  
  view {
    query          = <<-SQL
      SELECT
        *
      FROM `${var.project_id}.${var.dataset_id}.cf_logs`
      WHERE NOT REGEXP_CONTAINS(
        sc_content_type,
        r'^(image/|text/css|application/(javascript|x-javascript)|application/font|font/|image/vnd\.microsoft\.icon)'
      )
      AND sc_content_type IS NOT NULL
    SQL
    use_legacy_sql = false
  }
}

# logs_enriched view
resource "google_bigquery_table" "logs_enriched" {
  dataset_id          = google_bigquery_dataset.dam_dataset.dataset_id
  table_id            = "logs_enriched"
  deletion_protection = false
  
  view {
    query          = <<-SQL
      SELECT
        l.*,
        b.bot_flag,
        b.anomaly_score
      FROM `${var.project_id}.${var.dataset_id}.cf_logs_filtered` AS l
      LEFT JOIN `${var.project_id}.${var.dataset_id}.bot_ips` AS b
        ON l.c_ip = b.ip
        AND DATE(l.date) = b.log_date
    SQL
    use_legacy_sql = false
  }
  
  depends_on = [
    google_bigquery_table.cf_logs_filtered,
    google_bigquery_table.bot_ips
  ]
}

# Note: The BQML model (bot_model) needs to be created manually or via a separate process
# since it requires training data. Add this as a manual step in the README.