# frozen_string_literal: true

module ClaimsApi
  module PageSizeValidation
    extend ActiveSupport::Concern
    included do
      def validate_documents_page_size
        errors = documents.reduce([]) do |memo, doc|
          if valid_page_size?(doc)
            memo
          else
            memo << json_api_page_size_error(doc)
          end
        end
        render json: { errors: errors }, status: 422 unless errors.empty?
      end

      def valid_page_size?(file)
        size_in_inches = PdfInfo::Metadata.read(file.path).page_size_inches
        size_in_inches[:height] <= 11 && size_in_inches[:width] <= 11
      end

      def json_api_page_size_error(document)
        {
          status: 422,
          source: document.original_file_name,
          details: "#{document.original_file_name} exceeds the maximum page dimensions of 11 in x 11 in"
        }
      end
    end
  end
end
