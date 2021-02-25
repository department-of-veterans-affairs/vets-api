# frozen_string_literal: true

require 'pdf_info'

module AppealsApi
  module EvidenceSubmission
    class UploadValidator
      include SentryLogging

      def initialize(upload)
        @document = upload[:document]
      end

      def call
        return file_type_error unless pdf_metadata_present?
        return file_size_error unless valid_file_size?
        return max_dimension_error unless valid_page_dimensions?

        successful_validation_message
      end

      private

      def pdf_metadata_present?
        @pdf_metadata = PdfInfo::Metadata.read(@document)
      rescue PdfInfo::MetadataReadError => e
        @pdf_error = I18n.t('appeals_api.evidence_submission.pdf_read_error')
        log_exception_to_sentry(e, {}, {}, :warn)
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
        # TODO: need to figure this out
        @file_size ||= @document.try(:length) || @document.try(:size)
      end

      # rubocop:disable Layout/SpaceInsideHashLiteralBraces
      # rubocop:disable Layout/HashAlignment
      def file_type_error
        content_type = @document.content_type
        extension = File.extname(@document)
        pdf_ext_error = I18n.t('appeals_api.evidence_submission.pdf_extension_message')
        { document: {
            status: 'error',
            filename:  @document.original_filename,
            detail: I18n.t('appeals_api.evidence_submission.unsupported_file_type'),
            content_type: content_type,
            file_extension: extension == '.pdf' ? pdf_ext_error : extension
        }}
      end

      def max_dimension_error
        msg = I18n.t('appeals_api.evidence_submission.max_dimensions_error', max_dimensions: '11 inches x 11 inches')
        log_exception_to_sentry(UploadValidationError.new(msg), {}, {}, :warn)
        { document: {
            status: 'error',
            filename:  @document.original_filename,
            pages: @pdf_metadata.pages,
            detail: msg,
            file_dimensions: {
              "height": @dimensions[:height],
              "width": @dimensions[:width]
            }
        }}
      end

      def file_size_error
        msg = I18n.t('appeals_api.evidence_submission.max_file_size_error', max_file_size: '100 megabytes')
        log_exception_to_sentry(UploadValidationError.new(msg), {}, {}, :warn)
        { document: {
            status: 'error',
            filename:  @document.original_filename,
            pages: @pdf_metadata.pages,
            detail: msg,
            file_size: "#{current_file_size} MB"
        }}
      end

      def successful_validation_message
        msg = I18n.t('appeals_api.evidence_submission.successful_validation')
        { document: {
            status: 'accepted',
            filename:  @document.original_filename,
            pages: @pdf_metadata.pages,
            detail: msg,
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
