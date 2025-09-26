# frozen_string_literal: true

module SM
  class Client
    module Attachments
      ##
      # Generate a presigned URL (upstream) used for large attachment upload flow.
      # @param file [ActionDispatch::Http::UploadedFile]
      # @return [Hash] raw upstream response body (already parsed by middleware)
      def create_presigned_url_for_attachment(file)
        attachment_name = File.basename(file.original_filename, File.extname(file.original_filename))
        file_extension = File.extname(file.original_filename).delete_prefix('.')

        query_params = {
          attachmentName: attachment_name,
          fileExtension: file_extension
        }

        perform(:get, 'attachment/presigned-url', query_params, token_headers).body
      end

      ##
      # Retrieve a message attachment.
      # Upstream may return:
      #   1. A binary file (traditional)
      #   2. A JSON object w/ S3 metadata { url, mimeType, name }
      #   3. A plain URL (string) – treated like #2
      #
      # If an S3 URL object is returned we fetch the file and return its binary contents.
      #
      # @param message_id [Integer]
      # @param attachment_id [Integer]
      # @return [Hash] { body: binary_data_or_raw, filename: String }
      def get_attachment(message_id, attachment_id)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        response = perform(:get, path, nil, token_headers)
        data = response.body[:data] if response.body.is_a?(Hash)

        if data.is_a?(Hash) && data[:url] && data[:mime_type] && data[:name]
          fetch_from_presigned_url(data)
        else
          filename = response.response_headers['content-disposition']
                             &.gsub(CONTENT_DISPOSITION, '')
                             &.gsub(/%22|"/, '')
          { body: response.body, filename: }
        end
      end

      private

      def fetch_from_presigned_url(data)
        url = data[:url]
        uri = URI.parse(url)
        file_response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.get(uri.request_uri)
        end
        unless file_response.is_a?(Net::HTTPSuccess)
          Rails.logger.error('Failed to fetch attachment from presigned URL')
          raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_URL_FETCH_ERROR', {}, file_response.code)
        end
        { body: file_response.body, filename: data[:name] }
      end

      # Upload single large attachment to upstream S3 (PUT to presigned URL).
      # Raises SM_UPLOAD_ATTACHMENT_ERROR on failure.
      def upload_attachment_to_s3(file, presigned_url)
        uri = URI.parse(presigned_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')

        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = file.content_type
        request.body_stream = file
        request.content_length = file.size

        response = http.request(request)
        return if response.is_a?(Net::HTTPSuccess)

        Rails.logger.error("Failed to upload Messaging attachment to S3: #{response.body}")
        raise Common::Exceptions::BackendServiceException.new('SM_UPLOAD_ATTACHMENT_ERROR', 500)
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
          'lgAttachmentId' => uploaded_file_name
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

      # Internal: create message (or reply) with large attachments via presigned URL workflow.
      def create_message_with_lg_attachments_request(path, args)
        uploads = args.delete(:uploads)
        raise Common::Exceptions::ValidationErrors, 'uploads must be an array' unless uploads.is_a?(Array)

        require 'concurrent-ruby'
        futures = uploads.map { |file| Concurrent::Promises.future { build_lg_attachment(file) } }
        lg_attachments = Concurrent::Promises.zip(*futures).value!

        payload = form_large_attachment_payload(args[:message], lg_attachments)
        custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
        json = perform(:post, path, payload, custom_headers).body
        Message.new(json[:data].merge(json[:metadata]))
      end
    end
  end
end
