# frozen_string_literal: true

require 'sm/client/attachment_streaming'

module SM
  class Client < Common::Client::Base
    ##
    # Module containing attachment-related methods for the SM Client
    #
    include Vets::SharedLogging
    module Attachments
      include AttachmentStreaming

      CONTENT_DISPOSITION = 'attachment; filename='

      ##
      # Retrieve a message attachment. Returns either a binary file or fetches from S3 presigned URL.
      #
      # @deprecated Prefer {#stream_attachment} for memory-efficient downloads, especially for large files.
      #   This method loads the entire attachment into memory, which can cause memory exhaustion
      #   for files up to 25MB under concurrent load. See va.gov-team#131335 for migration plan.
      #
      # @param message_id [Fixnum] the message id
      # @param attachment_id [Fixnum] the attachment id
      # @return [Hash] object with binary file content and filename { body: binary_data, filename: string }
      def get_attachment(message_id, attachment_id)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        response = perform(:get, path, nil, token_headers)
        data = response.body[:data] if response.body.is_a?(Hash)

        if s3_attachment?(data)
          uri = URI.parse(data[:url])
          file_response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            http.get(uri.request_uri)
          end
          unless file_response.is_a?(Net::HTTPSuccess)
            Rails.logger.error('Failed to fetch attachment from presigned URL')
            raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_URL_FETCH_ERROR', {},
                                                                  file_response.code)
          end
          return { body: file_response.body, filename: data[:name] }
        end

        filename = response.response_headers['content-disposition']&.gsub(CONTENT_DISPOSITION, '')&.gsub(/%22|"/, '')
        { body: response.body, filename: }
      end

      ##
      # Stream a message attachment without loading full content into memory.
      # Uses raw Net::HTTP to stream directly from MHV or S3, bypassing Faraday buffering.
      #
      # This method is preferred over {#get_attachment} for large files (up to 25MB) as it:
      # - Streams data in chunks rather than buffering the entire file
      # - Maintains constant memory usage regardless of file size
      # - Supports both direct MHV binary responses and S3 presigned URL redirects
      #
      # @example Streaming to ActionController::Live response
      #   client.stream_attachment(message_id, attachment_id, header_callback) do |chunk|
      #     response.stream.write(chunk)
      #   end
      #
      # @param message_id [Fixnum] the message id
      # @param attachment_id [Fixnum] the attachment id
      # @param header_callback [Proc] called with response headers as array of [key, value] pairs
      #   for setting Content-Type and Content-Disposition on the response
      # @yield [String] streams chunks of the attachment data (typically 8KB) to the caller
      # @raise [Common::Exceptions::BackendServiceException] if the attachment cannot be fetched
      def stream_attachment(message_id, attachment_id, header_callback, &block)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        track_with_status('attachment.stream') do
          stream_from_mhv(path, header_callback, &block)
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
