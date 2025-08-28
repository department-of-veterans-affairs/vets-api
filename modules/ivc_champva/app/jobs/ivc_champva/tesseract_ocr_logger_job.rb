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
    # @param attachment_record_id [Integer] The ID of the attachment record to be processed
    # @param attachment_id [String] The attachment type ID of the attachment being processed, see
    # SupportingDocumentValidator.VALIDATOR_MAP
    # @param [User] current_user The current user
    def perform(form_id, uuid, attachment_record_id, attachment_id, current_user) # rubocop:disable Metrics/MethodLength
      return unless Flipper.enabled?(:champva_enable_ocr_on_submit, current_user)

      Rails.logger.info(
        "IvcChampva::TesseractOcrLoggerJob Beginning job for form_id: #{form_id}, uuid: #{uuid}," \
        " attachment_record_id: #{attachment_record_id}, attachment_id: #{attachment_id}"
      )

      # Find the attachment record
      attachment = get_attachment(attachment_record_id)
      return if attachment.blank?

      begin
        # Track sample size for this experiment
        monitor.track_experiment_sample_size('tesseract_ocr_validator', uuid)

        begin
          # Create a tempfile from the persistent attachment object
          tempfile = IvcChampva::TempfileHelper.tempfile_from_attachment(attachment, form_id)
          file_path = tempfile.path

          # Ensure the file exists before processing
          raise Errno::ENOENT, 'File path is nil' if file_path.nil?
          raise Errno::ENOENT, 'File not found' unless File.exist?(file_path)

          # Run Tesseract OCR on the file
          result = run_ocr(file_path, uuid, attachment_id)
        ensure
          # Clean up the tempfile
          tempfile&.close!
        end

        # Log the OCR result
        log_result(result, uuid)
      rescue => e
        Rails.logger.error("IvcChampva::TesseractOcrLoggerJob failed with error: #{e.message}")
        monitor.track_experiment_error('tesseract_ocr_validator', e.class.name, uuid, e.message)
      end
    end

    def get_attachment(attachment_record_id)
      attachment = PersistentAttachments::MilitaryRecords.find_by(id: attachment_record_id)
      unless attachment
        Rails.logger.warn(
          "IvcChampva::TesseractOcrLoggerJob Attachment record not found for ID: #{attachment_record_id}."
        )
        return
      end

      # Verify attachment has a valid file before processing
      if attachment.file.blank?
        Rails.logger.warn(
          "IvcChampva::TesseractOcrLoggerJob Attachment #{attachment_record_id} has no file data"
        )
        return
      end

      attachment
    end

    ## Runs the Tesseract OCR validator
    # @param file_path [String] The path to the file to be processed
    # @param uuid [String, nil] The UUID associated with the attachment
    # @param attachment_id [String] The attachment type ID of the attachment being processed
    def run_ocr(file_path, uuid, attachment_id)
      Rails.logger.info('IvcChampva::TesseractOcrLoggerJob Starting OCR processing')
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      validator = IvcChampva::SupportingDocumentValidator.new(file_path, uuid, attachment_id:)
      result = validator.process

      Rails.logger.info('IvcChampva::TesseractOcrLoggerJob OCR processing has returned results')
      duration_ms = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

      # Track processing time for this experiment
      monitor.track_experiment_processing_time('tesseract_ocr_validator', duration_ms, uuid)

      result
    end

    ## Logs the OCR result
    # @param result [Hash] The result of the OCR validation
    # @param uuid [String, nil] The UUID associated with the attachment
    def log_result(result, uuid)
      # Track StatsD metrics for Datadog
      if result[:confidence].present?
        monitor.track_experiment_metric('tesseract_ocr_validator', 'confidence', result[:confidence],
                                        uuid)
      end
      if result[:is_valid].present?
        monitor.track_experiment_metric('tesseract_ocr_validator', 'validity', result[:is_valid],
                                        uuid)
      end

      # Calculate missing fields count for OCR (count empty/nil extracted fields)
      missing_fields_count = result[:extracted_fields]&.count { |_key, value| value.blank? } || 0
      monitor.track_experiment_metric('tesseract_ocr_validator', 'missing_fields_count', missing_fields_count, uuid)
    end

    ##
    # retrieve a monitor for tracking
    #
    # @return [IvcChampva::Monitor]
    #
    def monitor
      @monitor ||= IvcChampva::Monitor.new
    end
  end
end
