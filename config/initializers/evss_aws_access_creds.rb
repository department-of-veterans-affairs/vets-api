# frozen_string_literal: true

evss_s3_uploads = ENV['EVSS_S3_UPLOADS'] == 'true'
EVSS_AWS_ACCESS_CREDS = {
  aws_access_key_id: ENV['EVSS_AWS_ACCESS_KEY_ID'],
  aws_secret_access_key: ENV['EVSS_AWS_SECRET_ACCESS_KEY']
}
