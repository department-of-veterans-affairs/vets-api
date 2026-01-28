# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing streaming-related methods for attachment downloads
    #
    module AttachmentStreaming
      CHUNK_SIZE = 8192

      private

      def stream_s3_attachment(data, header_callback, &block)
        uri = URI.parse(data[:url])

        # Set response headers based on metadata
        headers = {
          'Content-Type' => data[:mime_type],
          'Content-Disposition' => "#{Attachments::CONTENT_DISPOSITION}\"#{data[:name]}\""
        }
        header_callback.call(headers.to_a)

        # Stream the file from S3 with timeouts to prevent hanging connections:
        # - open_timeout: max seconds to wait for TCP connection to establish
        # - read_timeout: max seconds to wait for any single chunk of data (resets per chunk)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10,
                                            read_timeout: 60) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request) do |file_response|
            validate_http_response(file_response)
            file_response.read_body(&block)
          end
        end
      end

      # Stream directly from MHV API using raw Net::HTTP to avoid Faraday buffering.
      # If MHV returns a JSON response with S3 URL, streams from S3 instead.
      def stream_from_mhv(path, header_callback, &block)
        uri = build_mhv_uri(path)
        request = build_mhv_request(uri)

        # Timeouts prevent hanging connections:
        # - open_timeout: max seconds to wait for TCP connection to establish
        # - read_timeout: max seconds to wait for any single chunk (longer for MHV due to API gateway latency)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10,
                                            read_timeout: 120) do |http|
          http.request(request) do |response|
            validate_http_response(response)

            # Check if response is JSON (S3 presigned URL) or binary attachment
            if json_response?(response)
              handle_json_response(response, header_callback, &block)
            else
              stream_binary_response(response, header_callback, &block)
            end
          end
        end
      end

      def build_mhv_uri(path)
        base_path = config.base_path.chomp('/')
        URI.parse("#{base_path}/#{path}")
      end

      def build_mhv_request(uri)
        request = Net::HTTP::Get.new(uri)
        token_headers.each { |key, value| request[key] = value }
        request
      end

      def json_response?(response)
        content_type = response['content-type'] || ''
        content_type.include?('application/json')
      end

      def handle_json_response(response, header_callback, &)
        # Read the small JSON body to get S3 URL
        body = response.read_body
        data = JSON.parse(body, symbolize_names: true)
        s3_data = data[:data]

        if s3_data.is_a?(Hash) && s3_data[:url] && s3_data[:mime_type] && s3_data[:name]
          stream_s3_attachment(s3_data, header_callback, &)
        else
          raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_INVALID_RESPONSE', {}, 500)
        end
      end

      def stream_binary_response(response, header_callback, &)
        content_type = response['content-type'] || 'application/octet-stream'
        content_disposition = response['content-disposition'] ||
                              "#{Attachments::CONTENT_DISPOSITION}\"attachment\""

        headers = {
          'Content-Type' => content_type,
          'Content-Disposition' => content_disposition
        }
        header_callback.call(headers.to_a)

        # True streaming - read body in chunks
        response.read_body(&)
      end

      def validate_http_response(response)
        return if response.is_a?(Net::HTTPSuccess)

        Rails.logger.error("Failed to fetch attachment: HTTP #{response.code}")
        raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_FETCH_ERROR', {},
                                                              response.code)
      end
    end
  end
end
