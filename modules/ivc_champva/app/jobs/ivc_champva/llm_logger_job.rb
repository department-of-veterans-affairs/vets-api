# frozen_string_literal: true

module IvcChampva
  class LlmLoggerJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :default

    ##
    # This job is called by the controller when a file is uploaded to /submit_supporting_documents
    # and is used to process the file via the pdf2image_llm_processor API and log the results
    #
    # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
    # @param [String] uuid The UUID of the attachment
    # @param [Integer] attachment_record_id The ID of the attachment record to be processed
    # @param [String] attachment_id The doc_type of the attachment
    # @param [User] current_user The current user
    def perform(form_id, uuid, attachment_record_id, attachment_id, current_user) # rubocop:disable Metrics/MethodLength
      return unless Flipper.enabled?(:champva_enable_llm_on_submit, current_user)

      Rails.logger.info(
        "IvcChampva::LlmLoggerJob Beginning job for form_id: #{form_id}, uuid: #{uuid}," \
        " attachment_record_id: #{attachment_record_id}, attachment_id: #{attachment_id}"
      )

      # Find the attachment record
      attachment = get_attachment(attachment_record_id)
      return if attachment.blank?

      begin
        # Track sample size for this experiment
        monitor.track_experiment_sample_size('llm_validator', uuid)

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          # Create a tempfile from the persistent attachment object
          tempfile = IvcChampva::TempfileHelper.tempfile_from_attachment(attachment, form_id)

          # Convert to PDF for LLM processing
          pdf_path = Common::ConvertToPdf.new(tempfile).run

          # Ensure the file exists before processing
          raise Errno::ENOENT, 'PDF path is nil' if pdf_path.nil?
          raise Errno::ENOENT, 'PDF file not found' unless File.exist?(pdf_path)

          llm_service = IvcChampva::LlmService.new
          llm_response = llm_service.process_document(
            form_id:,
            file_path: pdf_path,
            uuid:,
            attachment_id:
          )
        ensure
          # Clean up the tempfile
          tempfile&.close!
        end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

        # Track processing time for this experiment
        monitor.track_experiment_processing_time('llm_validator', duration_ms, uuid)

        log_llm_results(llm_response, uuid)
      rescue => e
        Rails.logger.error("IvcChampva::LlmLoggerJob #{uuid} failed with error: #{e.message}")
        monitor.track_experiment_error('llm_validator', e.class.name, uuid, e.message)
      end
    end

    def get_attachment(attachment_record_id)
      attachment = PersistentAttachments::MilitaryRecords.find_by(id: attachment_record_id)
      unless attachment
        Rails.logger.warn(
          "IvcChampva::LlmLoggerJob Attachment record not found for ID: #{attachment_record_id}."
        )
        return
      end

      # Verify attachment has a valid file before processing
      if attachment.file.blank?
        Rails.logger.warn(
          "IvcChampva::LlmLoggerJob Attachment #{attachment_record_id} has no file data"
        )
        return
      end

      attachment
    end

    private

    def log_llm_results(llm_response, uuid)
      unless llm_response.is_a?(Hash)
        Rails.logger.error(
          "IvcChampva::LlmLoggerJob #{uuid} unexpected LLM response format: #{llm_response.class}"
        )
        return
      end

      missing_fields = llm_response['missing_fields']
      missing_fields_count = missing_fields.is_a?(Array) ? missing_fields.length : 0
      Rails.logger.info("IvcChampva::LlmLoggerJob #{uuid} missing_fields_count: #{missing_fields_count}")

      if llm_response['confidence'].present?
        monitor.track_experiment_metric('llm_validator', 'confidence', llm_response['confidence'],
                                        uuid)
      end
      if llm_response['valid'].present?
        monitor.track_experiment_metric('llm_validator', 'validity', llm_response['valid'],
                                        uuid)
      end
      monitor.track_experiment_metric('llm_validator', 'missing_fields_count', missing_fields_count, uuid)
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
