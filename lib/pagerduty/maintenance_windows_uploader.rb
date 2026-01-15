# frozen_string_literal: true

module PagerDuty
  module MaintenanceWindowsUploader
    module_function

    def s3_bucket
      Settings.maintenance.aws.bucket
    end

    def new_s3_resource
      Aws::S3::Resource.new(
        region: Settings.maintenance.aws.region,
        access_key_id: Settings.maintenance.aws.access_key_id,
        secret_access_key: Settings.maintenance.aws.secret_access_key
      )
    end

    def upload_file(file)
      s3_resource = new_s3_resource
      obj = s3_resource.bucket(s3_bucket).object('maintenance_windows.json')

      if Aws::S3.const_defined?(:TransferManager)
        # Use TransferManager for efficient multipart uploads
        options = {
          acl: 'public-read',
          content_type: 'application/json',
          multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
        }
        Aws::S3::TransferManager.new(client: s3_resource.client).upload_file(
          file,
          bucket: s3_bucket,
          key: 'maintenance_windows.json',
          **options
        )
      else
        # Fall back to basic upload
        obj.upload_file(file, acl: 'public-read', content_type: 'application/json')
      end
    end
  end
end
