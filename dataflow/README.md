# Dataflow Support Files

このディレクトリには、Google Dataflow標準テンプレート（GCS_Text_to_BigQuery）で使用するサポートファイルが含まれています。

## ファイル構成

### transform.js
CloudFrontログをBigQuery形式に変換するJavaScript UDF（User-Defined Function）。
- タブ区切りのログをJSON形式に変換
- 数値・日付フィールドの型変換
- 無効なレコードのフィルタリング

### cf_logs_schema.json
BigQueryテーブルのスキーマ定義。
- CloudFrontログの全フィールドを定義
- データ型とNULL許容を指定

## 使用方法

これらのファイルはTerraformにより自動的にGCSにアップロードされ、Workflowから参照されます：

- `transform.js` → `gs://YOUR_DATAFLOW_BUCKET/scripts/transform.js`
- `cf_logs_schema.json` → `gs://YOUR_DATAFLOW_BUCKET/schemas/cf_logs_schema.json`

## 注意

カスタムPython Dataflowパイプラインは削除されました。現在はGoogle標準テンプレートを使用しています。