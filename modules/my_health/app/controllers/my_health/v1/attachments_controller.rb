# frozen_string_literal: true

require 'mime/types'

module MyHealth
  module V1
    class AttachmentsController < SMController
      include ActionController::Live

      ATTACHMENT_HEADERS = %w[Content-Type Content-Disposition].freeze

      def show
        message_id = params[:message_id]
        attachment_id = params[:id]
        
        # Set Content-Transfer-Encoding header for binary data
        response.headers['Content-Transfer-Encoding'] = 'binary'
        
        header_callback = lambda do |headers|
          headers.each do |k, v|
            if ATTACHMENT_HEADERS.include?(k)
              # For Content-Disposition, format it to match Rails send_data format
              if k == 'Content-Disposition' && v.match?(/filename=/)
                # Extract filename from header
                filename = v.match(/filename=["']?([^"';]+)["']?/)[1] rescue nil
                if filename
                  # Format as Rails does with send_data: both filename and filename* (RFC 5987)
                  encoded_filename = CGI.escape(filename).gsub('+', '%20')
                  response.headers[k] = "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{encoded_filename}"
                  
                  # Determine correct Content-Type based on filename extension
                  mime_types = MIME::Types.of(filename)
                  if mime_types.any?
                    response.headers['Content-Type'] = mime_types.first.content_type
                  end
                else
                  response.headers[k] = v
                end
              elsif k == 'Content-Type'
                # Skip setting Content-Type here; it will be set from filename extension above
                # unless no filename was found in the Content-Disposition header
              end
            end
          end
        end

        begin
          client.stream_attachment(message_id, attachment_id, header_callback) do |chunk|
            response.stream.write(chunk)
          end
        rescue Common::Exceptions::RecordNotFound
          raise
        rescue Common::Exceptions::BackendServiceException
          raise
        rescue StandardError => e
          Rails.logger.error("Error streaming attachment #{attachment_id} for message #{message_id}: #{e.message}")
          raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_STREAM_ERROR', {}, 500)
        ensure
          response.stream.close if response.committed?
        end
      end
    end
  end
end
