# frozen_string_literal: true

require 'pdf_utilities/pdf_validator'

module VBADocuments
  class DocumentRequestValidator
    include PDFUtilities

    SUPPORTED_CONTENT_TYPES = %w[application/pdf].freeze
    MAX_FILE_SIZE_IN_BYTES = 100_000_000 # 100 MB
    DOCUMENT_NOT_PROVIDED_MSG = 'Document was not provided'
    DOCUMENT_NOT_A_PDF_MSG = 'Document is not a PDF'
    FILE_SIZE_LIMIT_EXCEEDED_MSG = 'Document exceeds the file size limit of 100 MB'
    DOCUMENT_FAILED_VALIDATION_MSG = 'Document failed validation'

    # Skip the check for owner/permissions password - only a user password invalidates the PDF
    PDF_VALIDATOR_OPTIONS = { check_encryption: false }.freeze

    attr_accessor :result

    def initialize(request)
      @request = request
      @errors = []
      @result = nil
    end

    def validate
      Rails.logger.info("#{log_prefix} starting")

      @errors = []
      @result = nil

      validate_headers
      if @errors.present?
        Rails.logger.info("#{log_prefix} found error in request header: #{@errors.join(',')}")
        @result = validation_error
        return @result
      end

      validate_body
      if @errors.present?
        Rails.logger.info("#{log_prefix} found error in request body: #{@errors.join(',')}")
        @result = validation_error
      else
        Rails.logger.info("#{log_prefix} returned success")
        @result = validation_success
      end
    end

    private

    def validate_headers
      content_type = @request.headers['Content-Type']
      content_length = @request.headers['Content-Length']
      content_length = @request.body.size.to_s if content_length.nil?

      Rails.logger.info("#{log_prefix} validating document with Content-Length of #{content_length} bytes")

      if content_length.to_i.zero?
        @errors << DOCUMENT_NOT_PROVIDED_MSG
      elsif SUPPORTED_CONTENT_TYPES.exclude?(content_type)
        @errors << DOCUMENT_NOT_A_PDF_MSG
      elsif content_length.to_i > MAX_FILE_SIZE_IN_BYTES
        @errors << FILE_SIZE_LIMIT_EXCEEDED_MSG
      end
    end

    def validate_body
      Tempfile.create("vba-documents-validate-#{SecureRandom.hex}.pdf", binmode: true) do |tempfile|
        tempfile << @request.body.read
        tempfile.rewind
        options = Flipper.enabled?(:vba_documents_skip_dimension_check) ? { check_page_dimensions: false } : {}
        validator = PDFValidator::Validator.new(tempfile, PDF_VALIDATOR_OPTIONS.merge(options))
        result = validator.validate

        unless result.valid_pdf?
          @errors << result.errors
          @errors.flatten!
        end
      end
    end

    def validation_error
      {
        errors: @errors.map do |error|
          {
            title: DOCUMENT_FAILED_VALIDATION_MSG,
            detail: error,
            status: '422'
          }
        end
      }
    end

    def validation_success
      {
        data: {
          type: 'documentValidation',
          attributes: {
            status: 'valid'
          }
        }
      }
    end

    def log_prefix
      self.class
    end
  end
end
