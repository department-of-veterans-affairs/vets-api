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

        # Stream the file from S3 with read_timeout to prevent hanging connections
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 60) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request) do |file_response|
            validate_http_response(file_response)
            file_response.read_body(&block)
          end
        end
      end

      def stream_direct_attachment(response, header_callback, &)
        content_type = response.response_headers['content-type'] || 'application/octet-stream'
        content_disposition = response.response_headers['content-disposition'] ||
                              "#{Attachments::CONTENT_DISPOSITION}\"attachment\""

        headers = {
          'Content-Type' => content_type,
          'Content-Disposition' => content_disposition
        }
        header_callback.call(headers.to_a)

        # For direct MHV responses, yield body in chunks for consistent interface
        chunk_body(response.body, &)
      end

      def validate_http_response(response)
        return if response.is_a?(Net::HTTPSuccess)

        Rails.logger.error('Failed to fetch attachment from presigned URL')
        raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_URL_FETCH_ERROR', {},
                                                              response.code)
      end

      def chunk_body(body)
        offset = 0
        while offset < body.bytesize
          chunk = body.byteslice(offset, CHUNK_SIZE)
          yield chunk if chunk
          offset += CHUNK_SIZE
        end
      end
    end
  end
end
