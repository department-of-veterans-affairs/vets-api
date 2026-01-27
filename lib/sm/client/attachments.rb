# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing attachment-related methods for the SM Client
    #
    include Vets::SharedLogging
    module Attachments
      CONTENT_DISPOSITION = 'attachment; filename='

      ##
      # Retrieve a message attachment
      # Endpoint returns either a binary file response, or object with AWS S3 URL details.
      # If the response is a URL (string or object format), it will fetch the file from that URL.
      # Object format includes: { "url": URL, "mimeType": "application/pdf", "name": "filename.pdf" }
      # 10MB limit of the MHV API gateway.
      #
      # @param message_id [Fixnum] the message id
      # @param attachment_id [Fixnum] the attachment id
      # @return [Hash] an object with binary file content and filename { body: binary_data, filename: string }
      #
      def get_attachment(message_id, attachment_id)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        response = perform(:get, path, nil, token_headers)
        data = response.body[:data] if response.body.is_a?(Hash)

        # Attachments that are stored in AWS S3 via presigned URL return an object with URL details
        if data.is_a?(Hash) && data[:url] && data[:mime_type] && data[:name]
          url = data[:url]
          uri = URI.parse(url)
          file_response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            http.get(uri.request_uri)
          end
          unless file_response.is_a?(Net::HTTPSuccess)
            Rails.logger.error('Failed to fetch attachment from presigned URL')
            raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_URL_FETCH_ERROR', {},
                                                                  file_response.code)
          end
          filename = data[:name]
          return { body: file_response.body, filename: }
        end

        # Default: treat as binary file response
        filename = response.response_headers['content-disposition']&.gsub(CONTENT_DISPOSITION, '')&.gsub(/%22|"/, '')
        { body: response.body, filename: }
      end

      ##
      # Stream a message attachment without loading full content into memory
      # Endpoint returns either a binary file response, or object with AWS S3 URL details.
      # If the response is a URL, it will stream the file from that URL.
      #
      # @param message_id [Fixnum] the message id
      # @param attachment_id [Fixnum] the attachment id
      # @param header_callback [Proc] a callable that will accept response headers
      # @yield [String] streams chunks of the attachment data to the caller
      #
      def stream_attachment(message_id, attachment_id, header_callback, &)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        response = perform(:get, path, nil, token_headers)
        data = response.body[:data] if response.body.is_a?(Hash)

        # Attachments that are stored in AWS S3 via presigned URL return an object with URL details
        if s3_attachment?(data)
          stream_s3_attachment(data, header_callback, &)
        else
          stream_direct_attachment(response, header_callback, &)
        end
      end

      ##
      # Create a presigned URL for an attachment
      # @param file [ActionDispatch::Http::UploadedFile] the file to be uploaded
      # @return [String] the MHV S3 presigned URL for the attachment
      #
      def create_presigned_url_for_attachment(file)
        attachment_name = File.basename(file.original_filename, File.extname(file.original_filename))
        file_extension = File.extname(file.original_filename).delete_prefix('.')

        query_params = {
          attachmentName: attachment_name,
          fileExtension: file_extension
        }

        perform(:get, 'attachment/presigned-url', query_params, token_headers).body
      end

      private

      def s3_attachment?(data)
        data.is_a?(Hash) && data[:url] && data[:mime_type] && data[:name]
      end

      def stream_s3_attachment(data, header_callback, &block)
        uri = URI.parse(data[:url])

        # Set response headers based on metadata
        headers = {
          'Content-Type' => data[:mime_type],
          'Content-Disposition' => "#{CONTENT_DISPOSITION}\"#{data[:name]}\""
        }
        header_callback.call(headers.to_a)

        # Stream the file from S3
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request) do |file_response|
            validate_http_response(file_response)
            # Stream the response body in chunks
            file_response.read_body(&block)
          end
        end
      end

      def stream_direct_attachment(response, header_callback, &)
        # Extract headers from the response
        content_type = response.response_headers['content-type'] || 'application/octet-stream'
        content_disposition = response.response_headers['content-disposition'] ||
                              "#{CONTENT_DISPOSITION}\"attachment\""

        headers = {
          'Content-Type' => content_type,
          'Content-Disposition' => content_disposition
        }
        header_callback.call(headers.to_a)

        # For direct MHV responses, the body is already loaded, but we yield it in chunks
        # to maintain consistent interface
        chunk_body(response.body, &)
      end

      def validate_http_response(response)
        return if response.is_a?(Net::HTTPSuccess)

        Rails.logger.error('Failed to fetch attachment from presigned URL')
        raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_URL_FETCH_ERROR', {},
                                                              response.code)
      end

      def chunk_body(body)
        chunk_size = 8192
        offset = 0
        while offset < body.bytesize
          chunk = body.byteslice(offset, chunk_size)
          yield chunk if chunk
          offset += chunk_size
        end
      end

      ##
      # Upload an attachment to S3 using a presigned URL
      # @param file [ActionDispatch::Http::UploadedFile] the file to be uploaded
      def upload_attachment_to_s3(file, presigned_url)
        uri = URI.parse(presigned_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')

        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = file.content_type
        request.body_stream = file
        request.content_length = file.size

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          clean_uri = URI::Generic.build(scheme: uri.scheme, host: uri.host, port: uri.port, path: uri.path)
          log_exception_to_rails("Failed to upload Messaging attachment to S3: \\#{clean_uri}")
          raise Common::Exceptions::BackendServiceException.new('SM_UPLOAD_ATTACHMENT_ERROR', 500)
        end
      end

      def extract_uploaded_file_name(url)
        URI.parse(url).path.split('/').last
      end

      def build_lg_attachment(file)
        url = create_presigned_url_for_attachment(file)[:data]
        uploaded_file_name = extract_uploaded_file_name(url)
        upload_attachment_to_s3(file, url)
        {
          'attachmentName' => file.original_filename,
          'mimeType' => file.content_type,
          'size' => file.size,
          'lgAttachmentId' => CGI.unescape(uploaded_file_name) # Decode URL-encoded filename
        }
      end

      def camelize_keys(hash)
        hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      end

      def form_large_attachment_payload(message, lg_attachments)
        camelized_message = camelize_keys(message)
        {
          'message' => Faraday::Multipart::ParamPart.new(
            camelized_message.to_json(camelize: true),
            'application/json'
          ),
          'lgAttachments[]' => Faraday::Multipart::ParamPart.new(
            lg_attachments.to_json,
            'application/json'
          )
        }
      end

      def create_message_with_lg_attachments_request(path, args)
        uploads = args.delete(:uploads)
        raise Common::Exceptions::ValidationErrors, 'uploads must be an array' unless uploads.is_a?(Array)

        # Parallel upload of attachments
        require 'concurrent-ruby'
        futures = uploads.map { |file| Concurrent::Promises.future { build_lg_attachment(file) } }
        lg_attachments = Concurrent::Promises.zip(*futures).value!

        # Build multipart payload
        payload = form_large_attachment_payload(args[:message], lg_attachments)
        custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
        json = perform(:post, path, payload, custom_headers).body
        Message.new(json[:data].merge(json[:metadata]))
      end
    end
  end
end
