# frozen_string_literal: true

require 'mime/types'

module MyHealth
  module V1
    class AttachmentsController < SMController
      include ActionController::Live

      def show
        message_id = params[:message_id]
        attachment_id = params[:id]

        # Set Content-Transfer-Encoding header for binary data
        response.headers['Content-Transfer-Encoding'] = 'binary'

        header_callback = lambda do |headers|
          process_response_headers(headers)
        end

        begin
          client.stream_attachment(message_id, attachment_id, header_callback) do |chunk|
            response.stream.write(chunk)
          end
        rescue Common::Exceptions::RecordNotFound, Common::Exceptions::BackendServiceException
          raise
        rescue => e
          error_msg = "Error streaming attachment #{attachment_id} for message #{message_id}"
          Rails.logger.error("#{error_msg}: #{e.class} - #{e.message}")
          raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_STREAM_ERROR', {}, 500)
        ensure
          response.stream.close if response.committed?
        end
      end

      private

      def process_response_headers(headers)
        headers_hash = headers.to_h

        # Process Content-Disposition first (may also set Content-Type based on filename)
        if (disposition = headers_hash['Content-Disposition']) && disposition.match?(/filename=/)
          process_content_disposition(disposition)
        end

        # Set Content-Type if not already determined from filename
        if (content_type = headers_hash['Content-Type']) && response.headers['Content-Type'].blank?
          response.headers['Content-Type'] = content_type
        end
      end

      def process_content_disposition(header_value)
        filename = extract_filename(header_value)
        return response.headers['Content-Disposition'] = header_value unless filename

        # Format as Rails does with send_data: both filename and filename* (RFC 5987)
        encoded_filename = CGI.escape(filename).gsub('+', '%20')
        response.headers['Content-Disposition'] =
          "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{encoded_filename}"

        # Determine correct Content-Type based on filename extension
        set_content_type_from_filename(filename)
      end

      def extract_filename(header_value)
        header_value.match(/filename=["']?([^"';]+)["']?/)[1]
      rescue NoMethodError
        nil
      end

      def set_content_type_from_filename(filename)
        mime_types = MIME::Types.of(filename)
        response.headers['Content-Type'] = mime_types.first.content_type if mime_types.any?
      end
    end
  end
end
