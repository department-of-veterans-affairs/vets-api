# frozen_string_literal: true

module IvcChampva
  class S3
    attr_reader :region, :bucket

    def initialize(region:, bucket:)
      @region = region
      @bucket = bucket
    end

    def put_object(key, file, metadata = {})
      Datadog::Tracing.trace('S3 Put File(s)') do
        metadata&.transform_values! { |value| value || '' }

        client.put_object({
                            bucket:,
                            key:,
                            body: File.read(file),
                            metadata:
                          })
        { success: true }
      rescue => e
        { success: false, error_message: "S3 PutObject failure for #{file}: #{e.message}" }
      end
    end

    def upload_file(key, file)
      Datadog::Tracing.trace('S3 Upload File(s)') do
        obj = resource.bucket(bucket).object(key)
        obj.upload_file(file)

        { success: true }
      rescue => e
        { success: false, error_message: "S3 UploadFile failure for #{file}: #{e.message}" }
      end
    end

    private

    def client
      @client ||= Aws::S3::Client.new(
        region:
      )
    end

    def resource
      @resource ||= Aws::S3::Resource.new(client:)
    end
  end
end
