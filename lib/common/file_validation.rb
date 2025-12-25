# frozen_string_literal: true

require 'common/pdf_helpers'
require 'pdf_utilities/pdf_validator'

module Common
  # Common::FileValidation provides utilities for validating uploaded files
  # including PDFs, images, and other document types.
  #
  # This module is designed to be reusable across different parts of the application,
  # including mobile APIs and web forms.
  #
  # Configuration Options:
  #   - size_limit_in_bytes: Maximum file size (default: 100 MB)
  #   - check_page_dimensions: Whether to validate PDF page dimensions (default: true)
  #   - check_encryption: Whether to check for PDF encryption (default: true)
  #   - width_limit_in_inches: Maximum page width for PDFs (default: 21 inches)
  #   - height_limit_in_inches: Maximum page height for PDFs (default: 21 inches)
  #
  # Example usage:
  #   validator = Common::FileValidation::Validator.new(file_path, {
  #     size_limit_in_bytes: 50.megabytes,
  #     check_encryption: true
  #   })
  #   result = validator.validate
  #   if result.valid?
  #     # Process file
  #   else
  #     # Handle errors: result.errors
  #   end
  module FileValidation
    # Configuration constants
    DEFAULT_SIZE_LIMIT = 100.megabytes
    DEFAULT_WIDTH_LIMIT = 78 # inches
    DEFAULT_HEIGHT_LIMIT = 101 # inches

    # Standard validation options for different use cases
    STANDARD_PDF_OPTIONS = {
      size_limit_in_bytes: DEFAULT_SIZE_LIMIT,
      check_page_dimensions: true,
      check_encryption: true,
      width_limit_in_inches: 21,
      height_limit_in_inches: 21
    }.freeze

    LARGE_PDF_OPTIONS = {
      size_limit_in_bytes: DEFAULT_SIZE_LIMIT,
      check_page_dimensions: true,
      check_encryption: true,
      width_limit_in_inches: DEFAULT_WIDTH_LIMIT,
      height_limit_in_inches: DEFAULT_HEIGHT_LIMIT
    }.freeze

    class ValidationResult
      attr_reader :errors

      def initialize
        @errors = []
      end

      def add_error(error_message)
        @errors << error_message
      end

      def valid?
        @errors.empty?
      end

      def to_h
        {
          valid: valid?,
          errors: @errors
        }
      end
    end

    class ValidationError < StandardError
      attr_reader :validation_errors

      def initialize(message, errors = [])
        super(message)
        @validation_errors = Array(errors)
      end
    end

    # Validator class that wraps PDFUtilities::PDFValidator::Validator
    # and provides a consistent interface for file validation
    class Validator
      attr_reader :file, :options

      def initialize(file, options = {})
        @file = file
        @options = STANDARD_PDF_OPTIONS.merge(options)
      end

      # Validates the file and returns a ValidationResult
      # @return [ValidationResult]
      def validate
        pdf_validator = PDFUtilities::PDFValidator::Validator.new(file, options)
        pdf_result = pdf_validator.validate

        result = ValidationResult.new
        pdf_result.errors.each { |error| result.add_error(error) }
        result
      end

      # Validates and raises an exception if validation fails
      # @raise [ValidationError] if validation fails
      # @return [ValidationResult]
      def validate!
        result = validate
        raise ValidationError.new('File validation failed', result.errors) unless result.valid?

        result
      end
    end
  end
end
