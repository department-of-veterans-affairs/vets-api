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
      obj = s3_resource.bucket(s3_bucket).object("#{SecureRandom.uuid}.csv")
      obj.upload_file(report_file, content_type: 'text/csv')
      obj.presigned_url(:get, expires_in: 1.week.to_i)
    end
  end
end
