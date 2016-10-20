# frozen_string_literal: true
require_dependency 'evss/aws_creds'

evss_s3_uploads = ENV['EVSS_S3_UPLOADS'] == 'true'
EVSS_AWS_ACCESS_CREDS = EVSS::AwsCreds.load(evss_s3_uploads)
