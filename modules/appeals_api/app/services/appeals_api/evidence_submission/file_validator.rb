# frozen_string_literal: true

require 'pdf_info'

module AppealsApi
  module EvidenceSubmission
    class FileValidator
      include SentryLogging

      class UploadValidationError < StandardError; end

      MAX_PAGE_SIZE = { width: 11, height: 11 }.freeze
      MAX_FILE_SIZE = 100.megabytes
      FILE_SIZE_STRING = '100 MB'

      def initialize(file)
        @file = file
        @filename = File.basename(@file)
      end

      def call
        return file_type_error unless pdf_metadata_present?
        return file_size_error unless valid_file_size?
        return max_dimension_error unless valid_page_dimensions?

        successful_validation_message
      end

      private

      def pdf_metadata_present?
        @pdf_metadata = PdfInfo::Metadata.read(@file)
      rescue PdfInfo::MetadataReadError => e
        @pdf_error = I18n.t('appeals_api.evidence_submission.pdf_read_error', filename: @filename)
        log_exception_to_sentry(e, {}, {}, :warn)
      ensure
        @pdf_metadata.present?
      end

      def valid_file_size?
        current_file_size <= MAX_FILE_SIZE
      end

      def current_file_size
        @file_size ||= @file.size
      end

      def valid_page_dimensions?
        @dimensions = @pdf_metadata.page_size_inches
        @dimensions[:height] <= MAX_PAGE_SIZE[:height] && @dimensions[:width] <= MAX_PAGE_SIZE[:width]
      end

      def file_type_error
        {
          status: 'error',
          detail: I18n.t('appeals_api.evidence_submission.unsupported_file_type', filename: @filename)
        }
      end

      def max_dimension_error
        msg = I18n.t('appeals_api.evidence_submission.max_dimensions_error',
                     max_dimensions: MAX_PAGE_SIZE,
                     filename: @filename)

        log_exception_to_sentry(UploadValidationError.new(msg), {}, {}, :warn)
        {
          status: 'error',
          detail: msg
        }
      end

      def file_size_error
        msg = I18n.t('appeals_api.evidence_submission.max_file_size_error',
                     max_size: FILE_SIZE_STRING,
                     filename: @filename)

        log_exception_to_sentry(UploadValidationError.new(msg), {}, {}, :warn)
        {
          status: 'error',
          detail: msg
        }
      end

      def successful_validation_message
        msg = I18n.t('appeals_api.evidence_submission.successful_validation', filename: @filename)
        {
          status: 'validated',
          detail: msg
        }
      end
    end
  end
end
