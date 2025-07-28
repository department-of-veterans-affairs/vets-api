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

      Rails.logger.info("IvcChampva::LlmLoggerJob Beginning job for form_id: #{form_id}, " \
                        "uuid: #{uuid}")

      begin
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        llm_service = IvcChampva::LlmService.new
        llm_response = llm_service.process_document(
          form_id:,
          file_path:,
          uuid:,
          attachment_id:
        )

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        Rails.logger.info("IvcChampva::LlmLoggerJob #{uuid} LLM processing completed in " \
                          "#{duration_ms} milliseconds")

        log_llm_results(llm_response, uuid)
      rescue => e
        Rails.logger.error("IvcChampva::LlmLoggerJob #{uuid} failed with error: #{e.message}")
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

      Rails.logger.info("IvcChampva::LlmLoggerJob #{uuid} doc_type: #{llm_response['doc_type']}")
      Rails.logger.info("IvcChampva::LlmLoggerJob #{uuid} doc_type_matches: #{llm_response['doc_type_matches']}")
      Rails.logger.info("IvcChampva::LlmLoggerJob #{uuid} valid: #{llm_response['valid']}")
      Rails.logger.info("IvcChampva::LlmLoggerJob #{uuid} confidence: #{llm_response['confidence']}")

      missing_fields = llm_response['missing_fields']
      missing_fields_count = missing_fields.is_a?(Array) ? missing_fields.length : 0
      Rails.logger.info("IvcChampva::LlmLoggerJob #{uuid} missing_fields_count: #{missing_fields_count}")
    end
  end
end
