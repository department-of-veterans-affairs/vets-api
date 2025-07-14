# frozen_string_literal: true

require 'llm_processor_api/client'

# This job runs our LLM processor on the specified file and logs the results.
module IvcChampva
  class LlmLoggerJob
    include Sidekiq::Worker

    sidekiq_options retry: false, queue: :default

    def perform(form_id, uuid, file_path, attachment_id)
      return unless Flipper.enabled?(:champva_enable_llm_on_submit)

      log_job_start(form_id, uuid, attachment_id)

      begin
        validate_file_exists(file_path)
        prompt = IvcChampva::PromptManager.get_prompt
        request_data = build_request_data(prompt, file_path, form_id, uuid, attachment_id)
        response = submit_to_llm_processor(request_data, uuid, attachment_id)
        log_result(response, attachment_id)
      rescue => e
        Rails.logger.error("IvcChampva::LlmLoggerJob #{attachment_id} failed with error: #{e.message}")
      end
    end

    def log_result(response, attachment_id)
      # TODO: can probably remove, unless there's a reason to log the response status
      log_response_metadata(response, attachment_id)

      return unless response.body.is_a?(String)

      begin
        outer_response = JSON.parse(response.body)
        answer_content = outer_response['answer']

        return unless answer_content.is_a?(String)

        llm_response = parse_llm_response(answer_content)
        log_specific_fields(llm_response, attachment_id)
      rescue JSON::ParserError => _e
        # don't log the error message to hide potential PII
        Rails.logger.error("IvcChampva::LlmLoggerJob #{attachment_id} failed to parse JSON response")
      end
    end

    private

    def log_job_start(form_id, uuid, attachment_id)
      Rails.logger.info(
        "IvcChampva::LlmLoggerJob Beginning job for form_id: #{form_id}," \
        " uuid: #{uuid}, attachment_id: #{attachment_id}"
      )
    end

    def validate_file_exists(file_path)
      raise Errno::ENOENT, 'File not found' unless File.exist?(file_path)
    end

    def build_request_data(prompt, file_path, form_id, uuid, attachment_id)
      {
        prompt:,
        file_path:,
        form_id:,
        uuid:,
        attachment_id:
      }
    end

    def submit_to_llm_processor(request_data)
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      llm_client = IvcChampva::LlmProcessorApi::Client.new
      response = llm_client.process_document(request_data[:uuid], 'llm_logger_job', request_data)

      duration_ms = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
      Rails.logger.info("IvcChampva::LlmLoggerJob #{request_data[:attachment_id]} LLM processing completed in " \
                        "#{duration_ms} milliseconds")

      response
    end

    def log_response_metadata(response, attachment_id)
      Rails.logger.info("IvcChampva::LlmLoggerJob #{attachment_id} response_status: #{response.status}")
    end

    def parse_llm_response(answer_content)
      cleaned_content = answer_content.strip
                                      .gsub(/^```json\s*/, '')  # Remove opening ```json
                                      .gsub(/\s*```$/, '')      # Remove closing ```
                                      .gsub(/\n/, '')           # Remove newlines

      JSON.parse(cleaned_content)
    end

    def log_specific_fields(llm_response, attachment_id)
      unless llm_response.is_a?(Hash)
        Rails.logger.error("IvcChampva::LlmLoggerJob #{attachment_id} unexpected LLM response format: " \
                           "#{llm_response.class}")
        return
      end

      Rails.logger.info("IvcChampva::LlmLoggerJob #{attachment_id} doc_type: #{llm_response['doc_type']}")
      Rails.logger.info("IvcChampva::LlmLoggerJob #{attachment_id} doc_type_matches: #{llm_response['doc_type_matches']}")
      Rails.logger.info("IvcChampva::LlmLoggerJob #{attachment_id} valid: #{llm_response['valid']}")
      Rails.logger.info("IvcChampva::LlmLoggerJob #{attachment_id} confidence: #{llm_response['confidence']}")

      missing_fields = llm_response['missing_fields']
      missing_fields_count = missing_fields.is_a?(Array) ? missing_fields.length : 0
      Rails.logger.info("IvcChampva::LlmLoggerJob #{attachment_id} missing_fields_count: #{missing_fields_count}")
    end
  end
end
