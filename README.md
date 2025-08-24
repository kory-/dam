# DAM - CloudFront Log Analysis and Bot Detection Pipeline

GCSに蓄積されたCloudFrontログを日次で処理し、機械学習による不正IP検出を行うデータパイプライン。

## 🏗️ アーキテクチャ

```
GCS (CloudFront Logs)
    ↓
Cloud Scheduler (4:00 JST)
    ↓
Workflows (Orchestration)
    ↓
Dataflow (Batch Import)
    ↓
BigQuery (cf_logs)
    ↓
特徴量集計 (ip_features)
    ↓
BQML推論 (bot_model)
    ↓
結果保存 (bot_ips)
    ↓
ビュー更新 (cf_logs_filtered, logs_enriched)
```

## 📋 前提条件

- GCP プロジェクト
- GCS バケット (CloudFrontログ用)
- BigQuery データセット
- リージョン (推奨: `asia-northeast1`)

## 🚀 セットアップ

### 1. 事前準備

```bash
# GCP CLIの認証
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# 必要なAPIの有効化（Terraformでも実行されますが念のため）
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable workflows.googleapis.com
gcloud services enable dataflow.googleapis.com
gcloud services enable bigquery.googleapis.com
```

### 2. BQML モデルの作成

bot_modelは事前に学習が必要です。以下のクエリを実行してモデルを作成：

```sql
CREATE OR REPLACE MODEL `YOUR_PROJECT.YOUR_DATASET.bot_model`
OPTIONS(model_type = 'AUTOENCODER')
AS
SELECT
    req_total,
    unique_uri,
    err_ratio,
    max_rps,
    ua_entropy
FROM `YOUR_PROJECT.YOUR_DATASET.ip_features`
WHERE log_date BETWEEN 'START_DATE' AND 'END_DATE';  -- 学習用データ期間
```

### 3. 変換スクリプトのアップロード

```bash
cd dataflow
# JavaScript変換関数をGCSにアップロード
gsutil cp transform.js gs://YOUR_DATAFLOW_BUCKET/scripts/transform.js
```

### 4. Terraform でインフラ構築

```bash
cd terraform

# terraform.tfvarsを作成（terraform.tfvars.exampleを参考に）
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集して環境に合わせた値を設定

# 初期化
terraform init

# プラン確認
terraform plan

# 適用
terraform apply
```

## 📊 データフロー

### 日次処理（毎日4:00 JST）

1. **Cloud Scheduler** が Workflows を起動
2. **Workflows** が以下を順次実行：
   - Dataflow ジョブを起動（前日分のログを取り込み）
   - ジョブ完了を待機
   - IP特徴量を更新（MERGE）
   - BQML で推論実行
   - 結果を bot_ips に保存

### テーブル構造

- **cf_logs**: CloudFrontログ（日付パーティション）
- **ip_features**: IP別の特徴量（日付パーティション）
  - req_total: 総リクエスト数
  - unique_uri: ユニークURI数
  - err_ratio: エラー率
  - max_rps: 最大RPS
  - ua_entropy: User-Agentエントロピー
- **bot_ips**: ボット判定結果（日付パーティション）
  - anomaly_score: 異常スコア
  - bot_flag: ボットフラグ

### ビュー

- **cf_logs_filtered**: 静的コンテンツを除外したログ
- **logs_enriched**: ボット判定結果付きログ

## 🔧 運用

### 手動実行

```bash
# 前日分を処理（パラメータなし）
gcloud workflows run dam-daily-pipeline \
  --location=YOUR_REGION \
  --project=YOUR_PROJECT_ID

# 特定日付を処理
gcloud workflows run dam-daily-pipeline \
  --location=YOUR_REGION \
  --data='{"target_date":"2025-05-07"}' \
  --project=YOUR_PROJECT_ID
```

### バックフィル（複数日の処理）

```bash
#!/bin/bash
# 複数日を連続処理
for date in 2025-05-01 2025-05-02 2025-05-03; do
  echo "Processing $date..."
  gcloud workflows run dam-daily-pipeline \
    --location=YOUR_REGION \
    --data="{\"target_date\":\"$date\"}" \
    --project=YOUR_PROJECT_ID
  sleep 10  # 次の実行まで少し待機
done
```

### モニタリング

```bash
# Workflows の実行状況確認
gcloud workflows executions list \
  --workflow=dam-daily-pipeline \
  --location=YOUR_REGION

# Dataflow ジョブの確認
gcloud dataflow jobs list --region=YOUR_REGION

# BigQuery ジョブの確認
bq ls -j -a -n 50
```

## 🛠️ トラブルシューティング

### Dataflow ジョブが失敗する場合

1. GCS のアクセス権限を確認
2. ログパターンが正しいか確認
3. Dataflow のクォータを確認

### BigQuery クエリが失敗する場合

1. テーブルのパーティションが存在するか確認
2. bot_model が作成されているか確認
3. データセットの権限を確認

### Workflows が失敗する場合

1. Cloud Loggingでエラーメッセージを確認：
```bash
gcloud logging read "resource.type=workflows.googleapis.com/Workflow" \
  --limit=50 --format=json
```

## 📝 注意事項

- **冪等性**: 同じ日付で再実行しても同じ結果になるよう設計
- **コスト**: Dataflowのワーカー数、BigQueryのスロット使用量に注意
- **遅延データ**: 前日分のログが遅れて到着する場合はバックフィルで対応

## 🔐 セキュリティ

- サービスアカウントは最小権限の原則に従って設定
- Dataflow用とWorkflows用で別々のサービスアカウントを使用
- データセット、バケットへのアクセスはリソースレベルで制限