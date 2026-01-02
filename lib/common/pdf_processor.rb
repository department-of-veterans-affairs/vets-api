# frozen_string_literal: true

require 'common/pdf_helpers'
require 'common/convert_to_pdf'

module Common
  class PdfProcessor

    DEFAULT_VALIDATOR_OPTIONS = {
      size_limit_in_bytes: 100.megabytes,
      check_page_dimensions: true,
      check_encryption: true,
      width_limit_in_inches: 78,
      height_limit_in_inches: 101
    }.freeze

    class ProcessingError < StandardError
      attr_reader :errors

      def initialize(message, errors = [])
        super(message)
        @errors = Array(errors)
      end
    end

    class ConversionError < ProcessingError; end
    class ValidationError < ProcessingError; end

    # @param attachment [Object] An attachment object that responds to :file, :file=, :save, :guid, and :warnings
    # @param password [String, nil] Optional password for encrypted PDFs
    # @param validator_options [Hash] Custom validation options (merged with defaults)
    def initialize(attachment, password: nil, validator_options: {})
      @attachment = attachment
      @password = password
      @validator_options = DEFAULT_VALIDATOR_OPTIONS.merge(validator_options)
      @decrypted_file_path = nil
    end

    # Main processing pipeline: convert → decrypt (if needed) → validate → save
    # @return [Object] The processed attachment
    # @raise [ConversionError] If file conversion fails
    # @raise [ValidationError] If PDF validation fails
    def process!
      pdf_path = convert_to_pdf
      pdf_path = decrypt_pdf(pdf_path) if password.present?
      validate_pdf_at_path(pdf_path)

      File.open(pdf_path, 'rb') do |pdf_file|
        attachment.file = pdf_file
        attachment.save
      end

      attachment
    rescue => e
      Rails.logger.error("PdfProcessor failed: #{e.message}")
      raise
    ensure
      cleanup_temporary_files(pdf_path)
    end

    private

    attr_reader :attachment, :password, :validator_options

    def cleanup_temporary_files(pdf_path)
      cleanup_decrypted_file
      Common::FileHelpers.delete_file_if_exists(pdf_path) if pdf_path != @decrypted_file_path
    end

    def cleanup_decrypted_file
      return unless @decrypted_file_path

      Common::FileHelpers.delete_file_if_exists(@decrypted_file_path)
    rescue => e
      Rails.logger.warn("Failed to cleanup decrypted temp file: #{e.message}")
    end

    def convert_to_pdf
      Rails.logger.info("Converting file to PDF for attachment #{attachment.guid}")
      pdf_path = Common::ConvertToPdf.new(attachment.file).run
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
      output_path = Tempfile.new(['decrypted', '.pdf']).path
      Common::PdfHelpers.unlock_pdf(pdf_path, password, output_path)
      @decrypted_file_path = output_path
      output_path
    rescue Common::Exceptions::UnprocessableEntity => e
      Rails.logger.error("PDF decryption failed: #{e.message}")
      raise ValidationError.new(
        'PDF decryption failed',
        [{
          title: 'Invalid password',
          detail: 'The password you entered is incorrect. Please try again.'
        }]
      )
    end

    def validate_pdf_at_path(file_path)
      Rails.logger.info("Validating PDF for attachment #{attachment.guid}")
      validator = PDFUtilities::PDFValidator::Validator.new(file_path, validator_options)
      validation_result = validator.validate

      unless validation_result.valid_pdf?
        Rails.logger.error("PDF validation failed: #{validation_result.errors}")

        if attachment.respond_to?(:warnings)
          validation_result.errors.each do |error|
            attachment.warnings << error
          end
        end

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
  end
end