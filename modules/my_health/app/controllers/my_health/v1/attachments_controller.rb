# frozen_string_literal: true

module MyHealth
  module V1
    class AttachmentsController < SMController
      def show
        # Try X-Accel-Redirect approach if feature flag enabled
        if Flipper.enabled?(:mhv_secure_messaging_stream_via_revproxy)
          begin
            metadata = client.get_attachment_metadata(params[:message_id], params[:id])
            
            if metadata.present?
              # S3-backed attachment - use X-Accel-Redirect for streaming
              Rails.logger.info('Streaming attachment via X-Accel-Redirect',
                                message_id: params[:message_id],
                                attachment_id: params[:id])
              stream_via_revproxy(metadata)
              return
            end
            # Fall through to legacy approach for non-S3 attachments
            Rails.logger.info('Attachment not S3-backed, using legacy stream',
                              message_id: params[:message_id],
                              attachment_id: params[:id])
          rescue => e
            # If metadata retrieval fails, fall back to legacy approach
            Rails.logger.warn('Failed to get attachment metadata, falling back to legacy stream',
                              message_id: params[:message_id],
                              attachment_id: params[:id],
                              error: e.message)
          end
        end

        # Legacy approach: load file into memory and stream from Rails
        response = client.get_attachment(params[:message_id], params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] if response.blank?

        send_data(response[:body], filename: response[:filename])
      end

      private

      def stream_via_revproxy(metadata)
        # Sanitize filename to prevent header injection
        safe_filename = sanitize_filename(metadata[:filename])
        
        # Encode the S3 URL for the internal proxy location
        encoded_url = CGI.escape(metadata[:s3_url])
        
        # Set headers for nginx X-Accel-Redirect
        response.headers['X-Accel-Redirect'] = "/internal-s3-proxy/#{encoded_url}"
        response.headers['Content-Type'] = metadata[:mime_type]
        response.headers['Content-Disposition'] = "attachment; filename=\"#{safe_filename}\""
        response.headers['Cache-Control'] = 'private, no-cache, no-store, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        
        # Return empty body - nginx will handle the actual file streaming
        head :ok
      end

      def sanitize_filename(filename)
        # Remove any characters that could cause header injection
        # Allow: letters, numbers, spaces, dots, hyphens, underscores
        filename.to_s.gsub(/[^\w\s.\-]/, '_').strip[0..255]
      end
    end
  end
end
