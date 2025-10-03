# frozen_string_literal: true

require 'llm_processor_api/client'
require 'llm_processor_api/mock_client'

module IvcChampva
  class LlmService
    def initialize
      @llm_client = create_client
    end

    ##
    # Process a document via the pdf2image_llm_processor API and return the parsed response
    #
    # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
    # @param [String] file_path The path to the file
    # @param [String] uuid The UUID of the attachment
    # @param [String] attachment_id The doc_type of the attachment
    def process_document(form_id:, file_path:, uuid:, attachment_id:)
      validate_file_exists(file_path)
      prompt = get_prompt(attachment_id)
      request_data = build_request_data(prompt:, form_id:, file_path:, uuid:, attachment_id:)
      response = submit_to_llm_processor(request_data, uuid)
      parse_response(response)
    end

    private

    ##
    # Create the appropriate client based on environment
    # Uses mock client for development/test environments, real client for staging/production
    def create_client
      if %w[staging production].include?(Rails.env)
        IvcChampva::LlmProcessorApi::Client.new
      else
        IvcChampva::LlmProcessorApi::MockClient.new
      end
    end

    def validate_file_exists(file_path)
      raise Errno::ENOENT, 'File not found' unless File.exist?(file_path)
    end

    def get_prompt(attachment_id)
      IvcChampva::PromptManager.get_prompt(attachment_id)
    end

    def build_request_data(prompt:, form_id:, file_path:, uuid:, attachment_id:)
      {
        prompt:,
        file_path:,
        form_id:,
        uuid:,
        attachment_id:
      }
    end

    def submit_to_llm_processor(request_data, uuid)
      @llm_client.process_document(uuid, 'llm_service', request_data)
    end

    def parse_response(response)
      return {} unless response.body.is_a?(Hash)

      answer = response.body['answer']
      return {} unless answer.is_a?(String)

      parse_llm_response(answer)
    end

    def parse_llm_response(answer_content)
      cleaned_content = answer_content.gsub(/^```json/, '') # Remove opening ```json
                                      .gsub(/```$/, '')      # Remove closing ```
                                      .gsub(/\n/, '')        # Remove newlines
                                      .strip                 # Remove leading/trailing whitespace

      JSON.parse(cleaned_content)
    rescue JSON::ParserError => e
      Rails.logger.error("IvcChampva::LlmService parse_llm_response failed with error: #{e.message}")
      {}
    end
  end
end
