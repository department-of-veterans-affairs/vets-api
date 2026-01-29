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
      STATSD_KEY_PREFIX = 'api.my_health.attachments'

      ##
      # Downloads a message attachment.
      # Routes to X-Accel-Redirect streaming or legacy send_data based on feature flag.
      #
      def show
        if Flipper.enabled?(:mhv_secure_messaging_stream_via_revproxy, current_user)
          show_with_streaming
        else
          show_legacy
        end
      end

      private

      ##
      # Streams attachment using X-Accel-Redirect for S3-backed files, or send_data for non-S3.
      # Falls back to legacy approach on error.
      #
      def show_with_streaming
        attachment_info = client.get_attachment_info(params[:message_id], params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] if attachment_info.blank?

        if attachment_info[:s3_url].present?
          log_info('Streaming attachment via X-Accel-Redirect')
          StatsD.increment("#{STATSD_KEY_PREFIX}.x_accel_redirect")
          stream_via_revproxy(attachment_info)
        else
          log_info('Attachment not S3-backed, using send_data')
          StatsD.increment("#{STATSD_KEY_PREFIX}.fallback", tags: ['reason:not_s3_backed'])
          send_data(attachment_info[:body], filename: attachment_info[:filename])
        end
      rescue => e
        Rails.logger.warn('Failed to get attachment info, falling back to legacy',
                          message_id: params[:message_id],
                          attachment_id: params[:id],
                          error: e.message)
        StatsD.increment("#{STATSD_KEY_PREFIX}.fallback", tags: ['reason:error'])
        show_legacy
      end

      ##
      # Legacy attachment download - fetches full binary content into Rails memory.
      # Used when feature flag is disabled or as fallback on error.
      #
      def show_legacy
        StatsD.increment("#{STATSD_KEY_PREFIX}.legacy")
        response = client.get_attachment(params[:message_id], params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] if response.blank?

        send_data(response[:body], filename: response[:filename])
      end

      ##
      # Logs an info message with attachment context.
      # @param message [String] the log message
      #
      def log_info(message)
        Rails.logger.info(message, message_id: params[:message_id], attachment_id: params[:id])
      end

      ##
      # Sets response headers for nginx X-Accel-Redirect streaming.
      # nginx will intercept and proxy the request to S3 directly.
      #
      # @param attachment_info [Hash] with :s3_url, :mime_type, :filename
      #
      def stream_via_revproxy(attachment_info)
        safe_filename = sanitize_filename(attachment_info[:filename])
        encoded_url = CGI.escape(attachment_info[:s3_url])
        headers = response.headers

        headers['X-Accel-Redirect'] = "/internal-s3-proxy/#{encoded_url}"
        headers['Content-Type'] = attachment_info[:mime_type]
        headers['Content-Disposition'] = "attachment; filename=\"#{safe_filename}\""
        headers['Cache-Control'] = 'private, no-cache, no-store, must-revalidate'
        headers['Pragma'] = 'no-cache'
        headers['Expires'] = '0'

        head :ok
      end

      ##
      # Sanitizes filename to prevent HTTP header injection attacks.
      #
      # @param filename [String] the original filename
      # @return [String] sanitized filename safe for Content-Disposition header
      #
      def sanitize_filename(filename)
        # Allow: letters, numbers, spaces (literal only, not \s which includes \r\n), dots, hyphens, underscores
        filename.to_s.gsub(/[^\w .-]/, '_').strip[0..255]
      end
    end
  end
end
