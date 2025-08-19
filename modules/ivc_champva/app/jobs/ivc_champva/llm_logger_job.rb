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
    # @param [String] file_path The path to the file
    # @param [String] attachment_id The doc_type of the attachment
    def perform(form_id, uuid, file_path, attachment_id)
      return unless Flipper.enabled?(:champva_enable_llm_on_submit)

      begin
        # Track sample size for this experiment
        monitor.track_experiment_sample_size('llm_validator', uuid)

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        llm_service = IvcChampva::LlmService.new
        llm_response = llm_service.process_document(
          form_id:,
          file_path:,
          uuid:,
          attachment_id:
        )

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

        # Track processing time for this experiment
        monitor.track_experiment_processing_time('llm_validator', duration_ms, uuid)

        log_llm_results(llm_response, uuid)
      rescue => e
        Rails.logger.error("IvcChampva::LlmLoggerJob #{uuid} failed with error: #{e.message}")
        monitor.track_experiment_error('llm_validator', e.class.name, uuid, e.message)
      end
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
