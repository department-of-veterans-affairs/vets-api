# frozen_string_literal: true

require 'ivc_champva/supporting_document_validator'

# This job runs our Tesseract OCR validator on the specified file and logs the results.
module IvcChampva
  class TesseractOcrLoggerJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :default

    ## Performs the job
    # @param form_id [String] The ID of the current form, e.g., 'vha_10_10d'
    # @param uuid [String, nil] The UUID associated with the attachment
    # @param file_path [String] The path to the file to be processed
    # @param attachment_id [String] The attachment type ID of the attachment being processed, see
    # SupportingDocumentValidator.VALIDATOR_MAP
    def perform(form_id, uuid, file_path, attachment_id)
      return unless Flipper.enabled?(:champva_enable_ocr_on_submit)

      Rails.logger.info(
        "IvcChampva::TesseractOcrLoggerJob Beginning job for form_id: #{form_id}, uuid: #{uuid}," \
        " attachment_id: #{attachment_id}"
      )

      begin
        start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

        # Ensure the file exists before processing
        raise Errno::ENOENT, 'File not found' unless File.exist?(file_path)

        # Run Tesseract OCR on the file
        validator = IvcChampva::SupportingDocumentValidator.new(file_path, uuid, attachment_id:)
        result = validator.process
        Rails.logger.info('IvcChampva::TesseractOcrLoggerJob OCR processing has returned results')

        duration_ms = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        Rails.logger.info("IvcChampva::TesseractOcrLoggerJob #{attachment_id} OCR processing completed in " \
                          "#{duration_ms} milliseconds")

        log_result(result, uuid)
      rescue => e
        Rails.logger.error("IvcChampva::TesseractOcrLoggerJob failed with error: #{e.message}")
      end
    end

    def log_result(result, uuid)
      # Log top level results
      Rails.logger.info("IvcChampva::TesseractOcrLoggerJob #{uuid} validator_type: #{result[:validator_type]}")
      Rails.logger.info("IvcChampva::TesseractOcrLoggerJob #{uuid} document_type: #{result[:document_type]}")
      Rails.logger.info("IvcChampva::TesseractOcrLoggerJob #{uuid} is_valid: #{result[:is_valid]}")
      Rails.logger.info("IvcChampva::TesseractOcrLoggerJob #{uuid} confidence: #{result[:confidence]}")

      # Log extracted fields but not their values
      # Values are not safe to log as they may contain PII
      result[:extracted_fields].each do |key, value|
        type = value.class
        length = value.is_a?(String) ? value.length : nil
        Rails.logger.info(
          "IvcChampva::TesseractOcrLoggerJob #{uuid} extracted_field: #{key}: " \
          "type=#{type}#{", length=#{length}" if length}"
        )
      end
    end
  end
end
