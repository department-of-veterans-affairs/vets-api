# frozen_string_literal: true

if Settings.test_user_dashboard.env == 'staging'
  ENV['BIGQUERY_CREDENTIALS'] = Settings.test_user_dashboard.bigquery.to_json
end
