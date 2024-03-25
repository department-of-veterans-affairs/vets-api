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

    def put_object(key, file, metadata = {})
      Datadog::Tracing.trace('S3 Put File(s)') do
        # Convert nil values to empty strings in the metadata
        metadata&.transform_values! { |value| value || '' }

        client.put_object({
                            bucket: Settings.ivc_forms.s3.bucket,
                            key:,
                            body: File.read(file),
                            metadata:,
                            acl: 'public-read'
                          })
        { success: true }
      rescue => e
        { success: false, error_message: "S3 PutObject failure for #{file}: #{e.message}" }
      end
    end

    private

    def client
      @client ||= Aws::S3::Client.new(
        region: Settings.ivc_forms.s3.region,
        access_key_id: Settings.ivc_forms.s3.aws_access_key_id,
        secret_access_key: Settings.ivc_forms.s3.aws_secret_access_key
      )
    end
  end
end
