# frozen_string_literal: true

require 'ivc_champva/monitor'

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

        begin
          response = client.put_object(
            bucket:,
            key:,
            body: File.read(file),
            metadata: metadata
          )
          result = { success: true }
        rescue => e
          result = { success: false, error_message: "S3 PutObject failure for #{file}: #{e.message}" }
        end

        if Flipper.enabled?(:champva_log_all_s3_uploads, @current_user)
          response ? handle_put_object_response(response, key, file) : handle_put_object_error(e)
        else
          result
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
    status_code = response.context.http_response.status_code
    if status_code == 200
      monitor.track_all_successful_s3_uploads(key)
      { success: true }
    else
      error_message = "S3 PutObject failure for #{file}: Status code: #{status_code}"
      if response.respond_to?(:body) && response.body.respond_to?(:read)
        error_message += ", Body: #{response.body.read}"
      end
      Rails.logger.error error_message
      { success: false, error_message: error_message }
    end
  end


    def handle_put_object_error(error)
      Rails.logger.error "S3 PutObject unexpected error: #{error.message}"
      { success: false, error_message: "S3 PutObject unexpected error: #{error.message.strip}" }
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
