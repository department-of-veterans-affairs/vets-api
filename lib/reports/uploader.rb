# frozen_string_literal: true

module Reports
  module Uploader
    module_function

    def s3_bucket
      Settings.reports.aws.bucket
    end

    def new_s3_resource
      Aws::S3::Resource.new(
        region: Settings.reports.aws.region,
        access_key_id: Settings.reports.aws.access_key_id,
        secret_access_key: Settings.reports.aws.secret_access_key
      )
    end

    def get_s3_link(report_file)
      s3_resource = new_s3_resource
      key = "#{SecureRandom.uuid}.csv"

      if Aws::S3.const_defined?(:TransferManager)
        # Use TransferManager for efficient multipart uploads
        options = {
          content_type: 'text/csv',
          multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
        }
        Aws::S3::TransferManager.new(client: s3_resource.client).upload_file(
          report_file,
          bucket: s3_bucket,
          key:,
          **options
        )
        obj = s3_resource.bucket(s3_bucket).object(key)
      else
        # Fall back to basic upload
        obj = s3_resource.bucket(s3_bucket).object(key)
        obj.upload_file(report_file, content_type: 'text/csv')
      end

      obj.presigned_url(:get, expires_in: 1.week.to_i)
    end
  end
end
