# frozen_string_literal: true

require 'pdf_info'

module ClaimsApi
  module DocumentValidations
    extend ActiveSupport::Concern
    # rubocop:disable Metrics/BlockLength
    included do
      def validate_documents_content_type
        render json: { errors: document_content_type_errors }, status: 422 unless document_content_type_errors.empty?
      end

      def validate_documents_page_size
        render json: { errors: document_page_size_errors }, status: 422 unless document_page_size_errors.empty?
      end

      def valid_page_size?(file)
        size_in_inches = PdfInfo::Metadata.read(file.path).page_size_inches
        size_in_inches[:height] <= 11 && size_in_inches[:width] <= 11
      end

      def document_page_size_errors
        @document_page_size_errors ||= documents.reduce([]) do |cur, doc|
          valid_page_size?(doc) ? cur : cur << json_api_page_size_error(doc)
        end
      end

      def document_content_type_errors
        @document_content_type_errors ||= documents.reduce([]) do |cur, document|
          pdf?(document) ? cur : cur << json_api_content_type_error(document)
        end
      end

      def pdf?(document)
        extension = document.original_filename.split('.').last
        ['application/pdf', 'text/plain'].include?(document.content_type) && extension.downcase == 'pdf'
      end

      def json_api_page_size_error(document)
        {
          status: 422,
          source: document.original_filename,
          detail: "#{document.original_filename} exceeds the maximum page dimensions of 11 in x 11 in"
        }
      end

      def json_api_content_type_error(document)
        {
          status: 422,
          source: document.original_filename,
          detail: "#{document.original_filename} must be in PDF format"
        }
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
