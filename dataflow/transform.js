/**
 * CloudFront ログ変換用 JavaScript UDF
 * タブ区切りのログを BigQuery スキーマに変換
 */
function transform(line) {
  // ヘッダー行をスキップ
  if (line.startsWith('#')) {
    return null;
  }
  
  // タブで分割
  const values = line.split('\t');
  
  // フィールド定義（CloudFront ログ形式）
  const fields = [
    'date', 'time', 'x_edge_location', 'sc_bytes', 'c_ip', 'cs_method',
    'cs_host', 'cs_uri_stem', 'sc_status', 'cs_referer', 'cs_user_agent',
    'cs_uri_query', 'cs_cookie', 'x_edge_result_type', 'x_edge_request_id',
    'x_host_header', 'cs_protocol', 'cs_bytes', 'time_taken',
    'x_forwarded_for', 'ssl_protocol', 'ssl_cipher',
    'x_edge_response_result_type', 'cs_protocol_version', 'fle_status',
    'fle_encrypted_fields', 'c_port', 'time_to_first_byte',
    'x_edge_detailed_result_type', 'sc_content_type', 'sc_content_len',
    'sc_range_start', 'sc_range_end'
  ];
  
  // フィールド数チェック
  if (values.length !== fields.length) {
    return null;
  }
  
  // レコード作成
  const record = {};
  for (let i = 0; i < fields.length; i++) {
    const field = fields[i];
    const value = values[i];
    
    // null値の処理
    if (value === '-' || value === '') {
      record[field] = null;
    }
    // 数値フィールドの処理
    else if (['sc_bytes', 'cs_bytes', 'sc_status', 'c_port', 'sc_content_len'].indexOf(field) !== -1) {
      record[field] = value === '-' ? null : parseInt(value);
    }
    // 浮動小数点フィールドの処理
    else if (['time_taken', 'time_to_first_byte'].indexOf(field) !== -1) {
      record[field] = value === '-' ? null : parseFloat(value);
    }
    // 文字列フィールド
    else {
      record[field] = value;
    }
  }
  
  // 必須フィールドのチェック
  if (!record.date || !record.c_ip) {
    return null;
  }
  
  return JSON.stringify(record);
}