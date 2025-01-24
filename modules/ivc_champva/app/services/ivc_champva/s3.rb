# frozen_string_literal: true

require 'ivc_champva/monitor'

module IvcChampva
  class S3
    attr_reader :region, :bucket

    def initialize(region:, bucket:)
      @region = region
      @bucket = bucket
      @monitor = Monitor.new
    end

    def put_object(key, file, metadata = {})
      Datadog::Tracing.trace('S3 Put File(s)') do
        metadata&.transform_values! { |value| value || '' }

        begin
          response = client.put_object(
            bucket: bucket,
            key: key,
            body: File.read(file),
            metadata: metadata
          )

          handle_put_object_response(response, key, file)
        rescue => e
          handle_put_object_error(e)
        end
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

    def monitor
      @monitor ||= IvcChampva::Monitor.new
    end

    private

    def handle_put_object_response(response, key, file)
      if response.status == 200
        monitor.track_all_successful_s3_uploads(key)
        { success: true }
      else
        error_message = "S3 PutObject failure for #{file}: Status code: #{response.status}"
        if response.respond_to?(:body) && response.body.respond_to?(:read)
          error_message += ", Body: #{response.body.read}"
        end
        Rails.logger.error error_message
        { success: false, error_message: error_message }
      end
    end

    def handle_put_object_error(error)
      Rails.logger.error "S3 PutObject unexpected error: #{error.message}"
      { success: false, error_message: "S3 PutObject unexpected error: #{error.message}" }
    end

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
