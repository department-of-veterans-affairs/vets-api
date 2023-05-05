# frozen_string_literal: true

require 'pdf_info'

module PDFUtilities
  def self.formatted_file_size(file_size_in_bytes)
    bytes_per_gb = 1_000_000_000
    bytes_per_mb = 1_000_000
    bytes_per_kb = 1_000

    if file_size_in_bytes >= bytes_per_gb
      "#{format('%g', (file_size_in_bytes.to_f / bytes_per_gb))} GB"
    elsif file_size_in_bytes >= bytes_per_mb
      "#{format('%g', (file_size_in_bytes.to_f / bytes_per_mb))} MB"
    elsif file_size_in_bytes >= bytes_per_kb
      "#{format('%g', (file_size_in_bytes.to_f / bytes_per_kb))} KB"
    else
      "#{file_size_in_bytes} bytes"
    end
  end

  module PDFValidator
    FILE_SIZE_LIMIT_EXCEEDED_MSG = 'Document exceeds the file size limit'
    PAGE_SIZE_LIMIT_EXCEEDED_MSG = 'Document exceeds the page size limit'
    USER_PASSWORD_MSG = 'Document is locked with a user password'
    OWNER_PASSWORD_MSG = 'Document is encrypted with an owner password'
    INVALID_PDF_MSG = 'Document is not a valid PDF'

    class ValidationResult
      attr_accessor :errors

      def initialize
        @errors = []
      end

      def add_error(error_message)
        @errors << error_message
      end

      def valid_pdf?
        @errors.empty?
      end
    end

    class Validator
      DEFAULT_OPTIONS = {
        size_limit_in_bytes: 100_000_000, # 100 MB
        check_page_dimensions: true,
        check_encryption: true,
        # Height/width limits are ignored if the check_page_dimensions option is false.
        width_limit_in_inches: 21,
        height_limit_in_inches: 21
      }.freeze

      attr_accessor :result, :pdf_metadata

      # 'file' can be a File, Tempfile, or a String file path
      def initialize(file, options = {})
        @file = file
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def validate
        @result = ValidationResult.new
        @pdf_metadata = nil

        check_file_size
        set_pdf_metadata
        check_encryption if @options[:check_encryption]
        check_page_size if @options[:check_page_dimensions]

        @result
      end

      private

      def check_file_size
        size_limit = @options[:size_limit_in_bytes].to_i
        if File.size(@file) > size_limit
          message = "#{FILE_SIZE_LIMIT_EXCEEDED_MSG} of #{PDFUtilities.formatted_file_size(size_limit)}"
          @result.add_error(message)
        end
      end

      def set_pdf_metadata
        @pdf_metadata = PdfInfo::Metadata.read(@file)
      rescue PdfInfo::MetadataReadError => e
        if e.message.include?('Incorrect password')
          @result.add_error(USER_PASSWORD_MSG)
        else
          @result.add_error(INVALID_PDF_MSG)
        end
      end

      def check_encryption
        @result.add_error(OWNER_PASSWORD_MSG) if @pdf_metadata.present? && @pdf_metadata.encrypted?
      end

      def check_page_size
        if @pdf_metadata.present?
          dimensions = @pdf_metadata.page_size_inches
          width_limit = @options[:width_limit_in_inches]
          height_limit = @options[:height_limit_in_inches]

          if dimensions[:width] > width_limit || dimensions[:height] > height_limit
            @result.add_error("#{PAGE_SIZE_LIMIT_EXCEEDED_MSG} of #{width_limit} in. x #{height_limit} in.")
          end
        end
      end
    end
  end
end
