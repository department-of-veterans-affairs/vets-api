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
      metadata&.transform_values! { |value| value || '' }

      begin
        response = client.put_object(
          bucket:,
          key:,
          body: File.read(file),
          metadata:
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

    def upload_file(key, file)
      obj = resource.bucket(bucket).object(key)
      obj.upload_file(file)

      { success: true }
    rescue => e
      { success: false, error_message: "S3 UploadFile failure for #{file}: #{e.message}" }
    end

    def monitor
      @monitor ||= IvcChampva::Monitor.new
    end

    private

    ##
    # Handles the response from a put_object operation.
    #
    # Extracts the status code from the response and tracks successful uploads.
    # If the status code is not 200, logs and returns an error message.
    #
    # @param response [Aws::S3::Types::PutObjectOutput] the S3 response object.
    # @param key [String] the key of the uploaded file.
    # @param file [String] the path to the file uploaded.
    # @return [Hash] a hash containing { success: true } on success or { success: false, error_message: String }
    # on failure.
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
        { success: false, error_message: }
      end
    end

    ##
    # Handles errors raised during the put_object operation.
    #
    # Logs the error and returns an error message.
    #
    # @param error [Exception] the exception raised.
    # @return [Hash] a hash containing { success: false, error_message: String }.
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
