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
      # Retrieve attachment info, returning S3 metadata for X-Accel-Redirect or body for legacy streaming.
      # This avoids duplicate requests by returning everything needed in one call.
      #
      # @param message_id [Fixnum] the message id
      # @param attachment_id [Fixnum] the attachment id
      # @return [Hash] attachment info with consistent format:
      #   - S3-backed: { s3_url: string, mime_type: string, filename: string, body: nil }
      #   - Non-S3:    { s3_url: nil, mime_type: nil, filename: string, body: binary_data }
      #
      def get_attachment_info(message_id, attachment_id)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        response = perform(:get, path, nil, token_headers)
        data = response.body[:data] if response.body.is_a?(Hash)

        # S3-backed attachments return metadata with presigned URL
        if data.is_a?(Hash) && data[:url] && data[:mime_type] && data[:name]
          {
            s3_url: data[:url],
            mime_type: data[:mime_type],
            filename: data[:name],
            body: nil
          }
        else
          # Non-S3: direct binary response
          filename = response.response_headers['content-disposition']&.gsub(CONTENT_DISPOSITION, '')&.gsub(/%22|"/, '')
          {
            s3_url: nil,
            mime_type: nil,
            filename:,
            body: response.body
          }
        end
      end

      ##
      # Retrieve a message attachment with full binary content (legacy method for mobile/fallback).
      # For S3-backed attachments, fetches content from the presigned URL.
      # @param message_id [Fixnum] the message id
      # @param attachment_id [Fixnum] the attachment id
      # @return [Hash] { body: binary_data, filename: string }
      def get_attachment(message_id, attachment_id)
        info = get_attachment_info(message_id, attachment_id)

        # Non-S3: body is already populated
        return { body: info[:body], filename: info[:filename] } if info[:body]

        # S3-backed: fetch content from presigned URL
        uri = URI.parse(info[:s3_url])
        file_response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.get(uri.request_uri)
        end

        unless file_response.is_a?(Net::HTTPSuccess)
          Rails.logger.error('Failed to fetch attachment from presigned URL')
          raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_URL_FETCH_ERROR', {},
                                                                file_response.code)
        end

        { body: file_response.body, filename: info[:filename] }
      end

      ##
      # Create a presigned URL for an attachment
      # @param file [ActionDispatch::Http::UploadedFile] the file to be uploaded
      # @return [String] the MHV S3 presigned URL for the attachment
      #
      def create_presigned_url_for_attachment(file)
        query_params = {
          attachmentName: File.basename(file.original_filename, File.extname(file.original_filename)),
          fileExtension: File.extname(file.original_filename).delete_prefix('.')
        }
        perform(:get, 'attachment/presigned-url', query_params, token_headers).body
      end

      private

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
