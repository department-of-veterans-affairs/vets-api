# frozen_string_literal: true

require 'common/pdf_helpers'
module SimpleFormsApi
  class ScannedFormProcessor
    PDF_VALIDATOR_OPTIONS = {
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
    class PersistenceError < ProcessingError; end

    def initialize(attachment, password: nil)
      @attachment = attachment
      @password = password
    end

    def process!
      pdf_path = convert_to_pdf
      pdf_path = decrypt_pdf(pdf_path) if password.present?
      validate_pdf_at_path(pdf_path)

      persist_processed_file(pdf_path)
      attachment
    rescue => e
      Rails.logger.error("ScannedFormProcessor failed: #{e.message}")
      raise
    ensure
      cleanup_decrypted_file
      File.delete(pdf_path) if pdf_path && File.exist?(pdf_path) && pdf_path != @decrypted_file_path
    end

    private

    attr_reader :attachment, :password

    def cleanup_decrypted_file
      return unless @decrypted_file_path

      File.delete(@decrypted_file_path)
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
      validator = PDFUtilities::PDFValidator::Validator.new(file_path, PDF_VALIDATOR_OPTIONS)
      validation_result = validator.validate

      unless validation_result.valid_pdf?
        Rails.logger.error("PDF validation failed: #{validation_result.errors}")
        validation_result.errors.each do |error|
          attachment.warnings << error
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

    def persist_processed_file(pdf_path)
      preexisting_error_details = format_error_details(attachment.errors)

      File.open(pdf_path, 'rb') do |pdf_file|
        attachment.file = pdf_file
        attachment.save!
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Attachment persistence validation failed: #{e.message}")
      raise PersistenceError.new(
        'File upload failed',
        resolved_persistence_errors(e, preexisting_error_details)
      )
    rescue => e
      raise if e.is_a?(PersistenceError)

      Rails.logger.error("Attachment persistence failed: #{e.message}")
      raise PersistenceError.new('File upload failed', default_persistence_errors)
    end

    def resolved_persistence_errors(exception, preexisting_error_details)
      record_details = format_error_details(exception.record&.errors) if exception.respond_to?(:record)
      message_details = format_error_details_from_strings(extract_messages_from_exception(exception.message))

      record_details.presence ||
        preexisting_error_details.presence ||
        message_details.presence ||
        default_persistence_errors
    end

    def format_error_details(errors)
      return [] unless errors.respond_to?(:full_messages) && errors.any?

      format_error_details_from_strings(errors.full_messages)
    end

    def format_error_details_from_strings(messages)
      return [] unless messages&.any?

      Array(messages).map do |message|
        {
          title: 'File upload failed',
          detail: message
        }
      end
    end

    def default_persistence_errors
      [{
        title: 'File upload failed',
        detail: 'We could not save your file. Please try again later.'
      }]
    end

    def extract_messages_from_exception(message)
      return [] unless message

      prefix = 'Validation failed: '
      if message.start_with?(prefix)
        message.delete_prefix(prefix).split(',').map(&:strip)
      else
        [message]
      end
    end
  end
end
