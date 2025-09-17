# frozen_string_literal: true

# simple_forms_api/app/services/scanned_form_processor.rb
module SimpleFormsApi
  class ScannedFormProcessor
    # PDF validation options matching Benefits Intake requirements
    PDF_VALIDATOR_OPTIONS = {
      size_limit_in_bytes: 100.megabytes, # 100 MB
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

    def initialize(attachment)
      @attachment = attachment
    end

    def process!
      convert_to_pdf
      validate_pdf
      @attachment.save
      @attachment
    rescue => e
      Rails.logger.error("ScannedFormProcessor failed: #{e.message}")
      raise
    end

    private

    attr_reader :attachment

    def convert_to_pdf
      Rails.logger.info("Converting file to PDF for attachment #{attachment.guid}")
      pdf_path = Common::ConvertToPdf.new(attachment.file).run

      pdf_file = File.open(pdf_path, 'rb')
      attachment.file = pdf_file
      
      Rails.logger.info("Successfully converted file to PDF")
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

    def validate_pdf
      Rails.logger.info("Validating PDF for attachment #{attachment.guid}")
      file_path = attachment.file.open.path
      
      validator = PDFUtilities::PDFValidator::Validator.new(file_path, PDF_VALIDATOR_OPTIONS)
      validation_result = validator.validate

      unless validation_result.valid_pdf?
        Rails.logger.error("PDF validation failed: #{validation_result.errors}")
        
        # Add validation errors to attachment warnings for frontend display
        validation_result.errors.each do |error|
          attachment.warnings << error
        end

        # Format errors for API response
        formatted_errors = validation_result.errors.map do |error|
          {
            title: 'File validation error',
            detail: error
          }
        end

        raise ValidationError.new('PDF validation failed', formatted_errors)
      end
      
      Rails.logger.info("PDF validation passed")
    end
  end
end