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
      obj.upload_file(file, acl: 'public-read', content_type: 'application/json')
    end
  end
end
