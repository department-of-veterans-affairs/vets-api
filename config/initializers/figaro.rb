# frozen_string_literal: true
Figaro.require_keys(
  'HOSTNAME',
  'CERTIFICATE_FILE',
  'KEY_FILE',
  'REDIS_HOST',
  'REDIS_PORT',
  'DB_ENCRYPTION_KEY',
  'MHV_HOST',
  'MHV_APP_TOKEN',
  'MHV_SM_HOST',
  'MHV_SM_APP_TOKEN',
  'EVSS_BASE_URL',
  'MVI_URL',
  'EVSS_S3_UPLOADS'
)
