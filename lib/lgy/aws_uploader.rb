# frozen_string_literal: true

module LGY
  module AwsUploader
    module_function

    def s3_bucket
      Settings.reports.aws.bucket
      # Settings.lgy.s3.bucket
    end

    def new_s3_resource
      Aws::S3::Resource.new(
        region: Settings.reports.aws.region,
        access_key_id: Settings.reports.aws.access_key_id,
        secret_access_key: Settings.reports.aws.secret_access_key
        # region: Settings.lgy.s3.region,
        # access_key_id: Settings.lgy.s3.access_key_id,
        # secret_access_key: Settings.lgy.s3.secret_access_key
      )
    end

    def get_s3_link(coe_file)
      s3_resource = new_s3_resource
      obj = s3_resource.bucket(s3_bucket).object("#{SecureRandom.uuid}.pdf")
      obj.upload_file(coe_file, content_type: 'application/pdf')
      obj.presigned_url(:get, expires_in: 1.week.to_i)
    end
  end
end
