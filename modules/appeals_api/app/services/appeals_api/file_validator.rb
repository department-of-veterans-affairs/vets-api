# frozen_string_literal: true

require 'pdf_info'

module AppealsApi
  class FileValidator
    include SentryLogging

    class UploadValidationError < StandardError; end

    MAX_PAGE_SIZE = { width: 11, height: 11 }.freeze
    MAX_FILE_SIZE = 100.megabytes
    MAX_SIZE_STRING = '100 MB'

    def initialize(file)
      @file = file
      @filename = File.basename(@file)
    end

    def call
      return [:error, file_type_error] unless pdf_metadata_present?
      return [:error, file_size_error] unless valid_file_size?
      return [:error, max_dimension_error] unless valid_page_dimensions?

      [:ok, {}]
    end

    private

    def pdf_metadata_present?
      @pdf_metadata = PdfInfo::Metadata.read(@file)
    rescue PdfInfo::MetadataReadError => e
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

    def file_size_mb
      current_file_size / 1_000_000
    end

    def valid_page_dimensions?
      @dimensions = @pdf_metadata.page_size_inches
      @dimensions[:height] <= MAX_PAGE_SIZE[:height] && @dimensions[:width] <= MAX_PAGE_SIZE[:width]
    end

    def file_type_error
      {
        title: 'Invalid file type',
        detail: log_error(:pdf_read_error),
        meta: { filename: @filename }
      }
    end

    def max_dimension_error
      {
        title: 'Invalid dimensions',
        detail: log_error(:max_dimensions_error),
        meta: { filename: @filename,
                max_page_size_inches: MAX_PAGE_SIZE,
                page_dimensions_inches: { width: @dimensions[:width], height: @dimensions[:height] } }
      }
    end

    def file_size_error
      {
        title: 'Invalid file size',
        detail: log_error(:max_file_size_error),
        meta: { filename: @filename, max_file_size: MAX_SIZE_STRING, file_size: "#{file_size_mb} MB" }
      }
    end

    def log_error(type)
      msg = I18n.t("appeals_api.evidence_submission.#{type}")
      log_exception_to_sentry(UploadValidationError.new(msg), {}, {}, :warn)
      msg
    end
  end
end
