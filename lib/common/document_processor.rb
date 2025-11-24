# frozen_string_literal: true

require 'common/convert_to_pdf'
require 'common/pdf_helpers'
require 'common/file_helpers'
require 'common/file_validation'

module Common
  # Common::DocumentProcessor provides a comprehensive service for processing
  # uploaded documents including:
  #   - Image to PDF conversion
  #   - PDF decryption (password-protected files)
  #   - File validation (size, dimensions, encryption)
  #
  # This service is designed to be reusable across different parts of the application,
  # including mobile APIs, web forms, and document upload services.
  #
  # Backend Validation Details:
  #   1. File Size: Validates file size against configurable limit (default: 100 MB)
  #   2. PDF Conversion: Converts images (.jpg, .png, etc.) to PDF format
  #   3. PDF Decryption: Unlocks password-protected PDFs with provided password
  #   4. Page Dimensions: Validates PDF pages don't exceed size limits
  #   5. Encryption Check: Ensures PDFs aren't encrypted with owner passwords
  #
  # Configuration Options:
  #   - validation_options: Hash of options for file validation
  #     - size_limit_in_bytes: Maximum file size (default: 100 MB)
  #     - check_page_dimensions: Whether to validate PDF page dimensions (default: true)
  #     - check_encryption: Whether to check for PDF encryption (default: true)
  #     - width_limit_in_inches: Maximum page width for PDFs (default: 78 inches)
  #     - height_limit_in_inches: Maximum page height for PDFs (default: 101 inches)
  #
  # Example usage:
  #   processor = Common::DocumentProcessor.new(uploaded_file, password: 'secret123')
  #   result = processor.process
  #   if result.success?
  #     # Use result.file_path for the processed PDF
  #   else
  #     # Handle errors: result.errors
  #   end
  #
  # For Shrine integration (like in SimpleFormsApi):
  #   processor = Common::DocumentProcessor.new(attachment.file, password: params['password'])
  #   result = processor.process
  #   if result.success?
  #     attachment.file = File.open(result.file_path, 'rb')
  #     attachment.save
  #   end
  class DocumentProcessor
    class ProcessingResult
      attr_reader :file_path, :errors, :warnings

      def initialize
        @file_path = nil
        @errors = []
        @warnings = []
      end

      def success=(value)
        @success = value
      end

      def success?
        @success == true
      end

      def file_path=(path)
        @file_path = path
      end

      def add_error(error)
        @errors << error
      end

      def add_warning(warning)
        @warnings << warning
      end

      def to_h
        {
          success: success?,
          file_path: @file_path,
          errors: @errors,
          warnings: @warnings
        }
      end
    end

    class ProcessingError < StandardError
      attr_reader :errors

      def initialize(message, errors = [])
        super(message)
        @errors = Array(errors)
      end
    end

    class ConversionError < ProcessingError; end
    class ValidationError < ProcessingError; end

    # Default validation options - can be customized for different use cases
    DEFAULT_VALIDATION_OPTIONS = FileValidation::LARGE_PDF_OPTIONS

    attr_reader :file, :password, :validation_options

    # Initialize a new DocumentProcessor
    # @param file [File, Tempfile, ActionDispatch::Http::UploadedFile] The file to process
    # @param password [String, nil] Optional password for encrypted PDFs
    # @param validation_options [Hash] Options for file validation
    def initialize(file, password: nil, validation_options: {})
      @file = file
      @password = password
      @validation_options = DEFAULT_VALIDATION_OPTIONS.merge(validation_options)
      @decrypted_file_path = nil
    end

    # Process the document through conversion, decryption, and validation
    # @return [ProcessingResult]
    def process
      result = ProcessingResult.new

      begin
        pdf_path = convert_to_pdf
        pdf_path = decrypt_pdf(pdf_path) if password.present?
        validate_pdf(pdf_path)

        result.file_path = pdf_path
        result.success = true
      rescue ConversionError, ValidationError => e
        result.success = false
        e.errors.each { |error| result.add_error(error) }
        cleanup_temp_files(pdf_path)
      rescue => e
        Rails.logger.error("DocumentProcessor failed: #{e.class} - #{e.message}")
        result.success = false
        result.add_error({
          title: 'Processing error',
          detail: 'An unexpected error occurred while processing the file'
        })
        cleanup_temp_files(pdf_path)
      end

      result
    end

    # Process the document and raise an exception on failure
    # @raise [ConversionError, ValidationError] if processing fails
    # @return [String] path to the processed PDF file
    def process!
      pdf_path = convert_to_pdf
      pdf_path = decrypt_pdf(pdf_path) if password.present?
      validate_pdf(pdf_path)
      pdf_path
    rescue => e
      cleanup_temp_files(pdf_path)
      raise
    end

    private

    def convert_to_pdf
      Rails.logger.info('Converting file to PDF')
      pdf_path = ConvertToPdf.new(file).run
      Rails.logger.info('Successfully converted file to PDF')
      pdf_path
    rescue => e
      Rails.logger.error("PDF conversion failed: #{e.message}")
      raise ConversionError.new(
        'File conversion failed',
        [{
          title: 'File conversion error',
          detail: 'Unable to convert file to PDF. Please ensure your file is valid and try again.'
        }]
      )
    end

    def decrypt_pdf(pdf_path)
      return pdf_path unless password.present?

      output_path = Tempfile.new(['decrypted', '.pdf']).path
      PdfHelpers.unlock_pdf(pdf_path, password, output_path)
      @decrypted_file_path = output_path
      Rails.logger.info('Successfully decrypted PDF')
      output_path
    rescue Exceptions::UnprocessableEntity => e
      Rails.logger.error("PDF decryption failed: #{e.message}")
      raise ValidationError.new(
        'PDF decryption failed',
        [{
          title: 'Invalid password',
          detail: 'The password you entered is incorrect. Please try again.'
        }]
      )
    end

    def validate_pdf(file_path)
      Rails.logger.info('Validating PDF')
      validator = FileValidation::Validator.new(file_path, validation_options)
      validation_result = validator.validate

      unless validation_result.valid?
        Rails.logger.error("PDF validation failed: #{validation_result.errors}")
        formatted_errors = validation_result.errors.map do |error|
          {
            title: 'File validation error',
            detail: error
          }
        end

        raise ValidationError.new('PDF validation failed', formatted_errors)
      end

      Rails.logger.info('PDF validation passed')
    end

    def cleanup_temp_files(pdf_path = nil)
      cleanup_decrypted_file
      FileHelpers.delete_file_if_exists(pdf_path) if pdf_path && pdf_path != @decrypted_file_path
    end

    def cleanup_decrypted_file
      return unless @decrypted_file_path

      File.delete(@decrypted_file_path)
    rescue => e
      Rails.logger.warn("Failed to cleanup decrypted temp file: #{e.message}")
    end
  end
end
