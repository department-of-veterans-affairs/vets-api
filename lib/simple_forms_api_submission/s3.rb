# frozen_string_literal: true

# S3 Module for simple form submission
# Return
#   { success: Boolean, [error_message: String] }
module SimpleFormsApiSubmission
  class S3
    attr_reader :region, :access_key_id, :secret_access_key, :bucket_name

    def initialize(region:, access_key_id:, secret_access_key:, bucket_name:)
      @region = region
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
      @bucket_name = bucket_name
    end

    def upload_file(key, file)
      obj = resource.bucket(bucket_name).object(key)
      obj.upload_file(file)

      { success: true }
    rescue => e
      { success: false, error_message: "S3 Upload failure for #{file}: #{e.message}" }
    end

    private

    def client
      @client ||= Aws::S3::Client.new(
        region: Settings.ivc_forms.s3.region,
        access_key_id: Settings.ivc_forms.s3.aws_access_key_id,
        secret_access_key: Settings.ivc_forms.s3.aws_secret_access_key
      )
    end

    def resource
      @resource ||= Aws::S3::Resource.new(client: client) # rubocop:disable Style/HashSyntax
    end
  end
end
