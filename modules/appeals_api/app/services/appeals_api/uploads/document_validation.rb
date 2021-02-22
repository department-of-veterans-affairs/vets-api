# frozen_string_literal: true

require 'pdf_info'

module AppealsApi
  module Uploads
    class DocumentValidation
      def initialize(upload)
        @document = upload[:document]
      end

      def validate
        raise UploadValidationError, non_pdf_error unless document_is_pdf?
        raise UploadValidationError, max_dimension_error unless valid_page_dimensions?
        raise UploadValidationError, file_size_error unless valid_file_size?
      end

      def document_is_pdf?
        @pdf_metadata = PdfInfo::Metadata.read(@document)
      rescue PdfInfo::MetadataReadError => e
        raise UploadValidationError, e
      end

      def valid_page_dimensions?
        dimensions = @pdf_metadata.page_size_inches
        dimensions[:height] <= 11 && dimensions[:width] <= 11
      end

      def valid_file_size?
        File.size(@document) <= 100.megabytes
      end

      def non_pdf_error
        I18n.t('appeals_api.uploads.non_pdf_error')
      end

      def max_dimension_error
        I18n.t('appeals_api.uploads.max_dimensions_error', max_dimensions: '11 inches x 11 inches')
      end

      def file_size_error
        I18n.t('appeals_api.uploads.max_file_size_error', max_file_size: '100 megabytes')
      end

      class UploadValidationError < StandardError; end
    end
  end
end
