# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing streaming-related methods for attachment downloads
    #
    module AttachmentStreaming
      # Network errors that can occur during streaming - wrapped to provide consistent error handling
      NETWORK_ERRORS = [
        Timeout::Error,
        Errno::ECONNRESET,
        Errno::ECONNREFUSED,
        Errno::ETIMEDOUT,
        Errno::EHOSTUNREACH,
        Net::ReadTimeout,
        Net::OpenTimeout,
        OpenSSL::SSL::SSLError,
        SocketError,
        EOFError
      ].freeze

      private

      def stream_s3_attachment(data, header_callback, &block)
        uri = URI.parse(data[:url])
        validate_https_scheme(uri)

        # Stream the file from S3 with timeouts to prevent hanging connections:
        # - open_timeout: max seconds to wait for TCP connection to establish
        # - read_timeout: max seconds to wait for any single chunk of data (resets per chunk)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request) do |file_response|
            validate_http_response(file_response)

            # Set response headers based on metadata and S3 response
            headers = {
              'Content-Type' => data[:mime_type],
              'Content-Disposition' => "#{Attachments::CONTENT_DISPOSITION}\"#{data[:name]}\""
            }
            # Forward Content-Length from S3 so clients know the file size
            headers['Content-Length'] = file_response['content-length'] if file_response['content-length']
            header_callback.call(headers.to_a)

            file_response.read_body(&block)
          end
        end
      rescue *NETWORK_ERRORS => e
        handle_network_error(e, 'S3')
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
            validate_http_response(response, raise_not_found: true)

            # Check if response is JSON (S3 presigned URL) or binary attachment
            if json_response?(response)
              handle_json_response(response, header_callback, &block)
            else
              stream_binary_response(response, header_callback, &block)
            end
          end
        end
      rescue *NETWORK_ERRORS => e
        handle_network_error(e, 'MHV')
      end

      def build_mhv_uri(path)
        URI.parse("#{config.base_path.chomp('/')}/#{path}")
      end

      def build_mhv_request(uri)
        request = Net::HTTP::Get.new(uri)
        token_headers.each { |key, value| request[key] = value }
        request
      end

      def json_response?(response)
        (response['content-type'] || '').include?('application/json')
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
        # Forward Content-Length so clients know the file size
        headers['Content-Length'] = response['content-length'] if response['content-length']
        header_callback.call(headers.to_a)

        # True streaming - read body in chunks
        response.read_body(&)
      end

      def validate_http_response(response, raise_not_found: false)
        return if response.is_a?(Net::HTTPSuccess)

        Rails.logger.error("Failed to fetch attachment: HTTP #{response.code}")

        # Raise RecordNotFound for MHV 404s so the controller returns proper 404 status
        # S3 404s are backend errors (expired/invalid presigned URL), not "record not found"
        raise Common::Exceptions::RecordNotFound, 'attachment' if raise_not_found && response.code == '404'

        raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_FETCH_ERROR', {},
                                                              response.code.to_i)
      end

      def validate_https_scheme(uri)
        return if uri.scheme == 'https'

        Rails.logger.error("Invalid S3 URL scheme: #{uri.scheme}")
        raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_INVALID_RESPONSE', {}, 500)
      end

      def handle_network_error(error, source)
        # Log only error class - error.message may contain PII from URL paths or API responses
        Rails.logger.error("Network error streaming attachment from #{source}: #{error.class}")
        raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_FETCH_ERROR', {}, 503)
      end
    end
  end
end
