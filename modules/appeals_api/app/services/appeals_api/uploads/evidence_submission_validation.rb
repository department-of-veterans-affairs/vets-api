# frozen_string_literal: true

require 'pdf_info'

module AppealsApi
  module Uploads
    class EvidenceSubmissionValidation
      include SentryLogging

      def initialize(upload)
        @document = upload[:document]
      end

      def validate
        return file_type_error unless pdf_metadata_present?

        if valid_file_size? && valid_page_dimensions?
          successful_validation_message
        elsif valid_file_size?
          max_dimension_error
        else
          file_size_error
        end
      end

      private

      def pdf_metadata_present?
        @pdf_metadata = PdfInfo::Metadata.read(@document)
      rescue PdfInfo::MetadataReadError => e
        @pdf_error = 'PdfInfo::MetadataReadError: Syntax Warning: May not be a PDF file'
        log_exception_to_sentry(e, nil, nil, 'warn')
      ensure
        @pdf_metadata.present?
      end

      def valid_file_size?
        current_file_size <= 100.megabytes
      end

      def valid_page_dimensions?
        @dimensions = @pdf_metadata.page_size_inches
        @dimensions[:height] <= 11 && @dimensions[:width] <= 11
      end

      def current_file_size
        @file_size ||= @document.length
      end

      # rubocop:disable Layout/SpaceInsideHashLiteralBraces
      # rubocop:disable Layout/HashAlignment
      def file_type_error
        content_type = @document.content_type
        extension = File.extname(@document)
        { document: {
          status: 'error',
          filename:  @document.original_filename,
          detail: I18n.t('appeals_api.uploads.unsupported_file_type'),
          content_type: content_type,
          file_extension: extension == '.pdf' ? '.pdf is likely an incorrect extension for this document' : extension
        }}
      end

      def max_dimension_error
        message = I18n.t('appeals_api.uploads.max_dimensions_error', max_dimensions: '11 inches x 11 inches')
        log_exception_to_sentry(UploadValidationError.new(message), {}, {}, :info)
        { document: {
          status: 'error',
          filename:  @document.original_filename,
          pages: @pdf_metadata.pages,
          detail: message,
          file_dimensions: {
            "height": @dimensions[:height],
            "width": @dimensions[:width]
          }
        }}
      end

      def file_size_error
        message = I18n.t('appeals_api.uploads.max_file_size_error', max_file_size: '100 megabytes')
        log_exception_to_sentry(UploadValidationError.new(message), {}, {}, :info)
        { document: {
          status: 'error',
          filename:  @document.original_filename,
          pages: @pdf_metadata.pages,
          detail: message,
          file_size: "#{current_file_size} MB"
        }}
      end

      def successful_validation_message
        message = I18n.t('appeals_api.uploads.successful_validation')
        { document: {
          status: 'accepted',
          filename:  @document.original_filename,
          pages: @pdf_metadata.pages,
          detail: message,
          file_dimensions: {
            "height": @dimensions[:height],
            "width": @dimensions[:width]
          }
        }}
      end
      # rubocop:enable Layout/SpaceInsideHashLiteralBraces
      # rubocop:enable Layout/HashAlignment

      class UploadValidationError < StandardError; end
    end
  end
end
