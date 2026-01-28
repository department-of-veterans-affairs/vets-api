# frozen_string_literal: true

module MyHealth
  module V1
    ##
    # Controller for downloading secure message attachments.
    #
    # Supports two streaming modes controlled by the `mhv_secure_messaging_stream_via_revproxy` feature flag:
    #
    # 1. **X-Accel-Redirect (nginx proxy)** - When enabled and attachment is S3-backed:
    #    - Rails authenticates/authorizes the request
    #    - Returns X-Accel-Redirect header pointing to internal nginx location
    #    - nginx streams file directly from S3 to client
    #    - Rails process freed immediately (zero memory overhead for file content)
    #
    # 2. **Legacy (send_data)** - Default behavior or fallback:
    #    - Downloads entire file into Rails memory
    #    - Streams to client via send_data
    #    - Rails process blocked for duration of transfer
    #
    # @note X-Accel-Redirect requires nginx configuration with an internal location
    #   that proxies to S3. See vsp-platform-revproxy for the `/internal-s3-proxy/` config.
    #
    # @see https://nginx.org/en/docs/http/ngx_http_core_module.html#internal
    #
    class AttachmentsController < SMController
      def show
        return if try_stream_via_revproxy

        # Legacy approach: load file into memory and stream from Rails
        response = client.get_attachment(params[:message_id], params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] if response.blank?

        send_data(response[:body], filename: response[:filename])
      end

      private

      # Attempts X-Accel-Redirect streaming if feature flag enabled and S3-backed.
      # @return [Boolean] true if handled via revproxy, false to fall back to legacy
      def try_stream_via_revproxy
        return false unless Flipper.enabled?(:mhv_secure_messaging_stream_via_revproxy)

        metadata = client.get_attachment_metadata(params[:message_id], params[:id])

        if metadata.present?
          log_info('Streaming attachment via X-Accel-Redirect')
          stream_via_revproxy(metadata)
          true
        else
          log_info('Attachment not S3-backed, using legacy stream')
          false
        end
      rescue => e
        Rails.logger.warn('Failed to get attachment metadata, falling back to legacy stream',
                          message_id: params[:message_id],
                          attachment_id: params[:id],
                          error: e.message)
        false
      end

      def log_info(message)
        Rails.logger.info(message, message_id: params[:message_id], attachment_id: params[:id])
      end

      # Sets response headers for nginx X-Accel-Redirect streaming.
      # nginx will intercept and proxy the request to S3 directly.
      # @param metadata [Hash] with :s3_url, :mime_type, :filename
      def stream_via_revproxy(metadata)
        safe_filename = sanitize_filename(metadata[:filename])
        encoded_url = CGI.escape(metadata[:s3_url])

        response.headers['X-Accel-Redirect'] = "/internal-s3-proxy/#{encoded_url}"
        response.headers['Content-Type'] = metadata[:mime_type]
        response.headers['Content-Disposition'] = "attachment; filename=\"#{safe_filename}\""
        response.headers['Cache-Control'] = 'private, no-cache, no-store, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'

        head :ok
      end

      # Sanitizes filename to prevent HTTP header injection attacks.
      # @param filename [String] the original filename
      # @return [String] sanitized filename safe for Content-Disposition header
      def sanitize_filename(filename)
        # Allow: letters, numbers, spaces (literal only, not \s which includes \r\n), dots, hyphens, underscores
        filename.to_s.gsub(/[^\w .-]/, '_').strip[0..255]
      end
    end
  end
end
