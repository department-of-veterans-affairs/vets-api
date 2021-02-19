# frozen_string_literal: true

module AppealsApi
  module Uploads
    class DocumentValidation
      def initialize(upload)
        @document = upload[:document]
      end

      def validate
        render json: { errors: json_api_content_type_error } unless validate_document_type
      end

      # rubocop:disable Layout/LineLength

      # application/octet-stream = arbitrary binary data
      # even when the supplied file is a pdf, the content_type is text/plain - why?
      def validate_document_type
        extension = @document.original_filename.split('.').last
        ['application/pdf', 'text/plain', 'application/octet-stream'].include?(@document.content_type) && extension.downcase == 'pdf'
      end

      def json_api_content_type_error
        {
            status: 422,
            source: @document.original_filename,
            detail: "#{@document.original_filename} must be in PDF format"
        }
      end
      # rubocop:enable Layout/LineLength
    end
  end
end
