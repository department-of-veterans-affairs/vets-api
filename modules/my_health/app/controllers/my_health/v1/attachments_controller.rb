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
          # Log only exception class - e.message may contain PII from failed JSON parsing or API responses
          Rails.logger.error("Error streaming attachment: #{e.class}")
          raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_STREAM_ERROR', {}, 500)
        ensure
          # Always attempt to close the stream, even if response wasn't committed
          # (e.g., if exception occurred before any data was written)
          response.stream.close rescue nil # rubocop:disable Style/RescueModifier
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

        # Forward Content-Length for download progress indicators and incomplete download detection.
        # We know exact size from upstream (S3/MHV) and stream all bytes faithfully.
        response.headers['Content-Length'] = headers_hash['Content-Length'] if headers_hash['Content-Length']
      end

      def process_content_disposition(header_value)
        filename = extract_filename(header_value)
        return response.headers['Content-Disposition'] = header_value unless filename

        # Build Content-Disposition with both filename (ASCII fallback) and filename* (RFC 5987)
        # 1. ASCII filename: escape backslashes and quotes per RFC 2616
        escaped_filename = filename.gsub('\\', '\\\\').gsub('"', '\\"')
        # 2. RFC 5987 filename*: percent-encode non-ASCII and special characters
        #    CGI.escape handles most cases but uses + for spaces; RFC 5987 requires %20
        encoded_filename = CGI.escape(filename).gsub('+', '%20')

        response.headers['Content-Disposition'] =
          "attachment; filename=\"#{escaped_filename}\"; filename*=UTF-8''#{encoded_filename}"

        # Determine correct Content-Type based on filename extension
        set_content_type_from_filename(filename)
      end

      def extract_filename(header_value)
        # Use Mail gem's Content-Disposition parser which handles RFC 5987 encoding
        Mail::ContentDispositionField.new(header_value).filename
      rescue ArgumentError, Mail::Field::IncompleteParseError
        nil
      end

      def set_content_type_from_filename(filename)
        mime_types = MIME::Types.of(filename)
        response.headers['Content-Type'] = mime_types.first.content_type if mime_types.any?
      end
    end
  end
end
