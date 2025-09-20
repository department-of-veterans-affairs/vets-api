# frozen_string_literal: true

module IvcChampva
  module LlmProcessorApi
    ##
    # Mock client for LLM processor API - used in non-production environments
    # Returns a simple mock response instead of making HTTP calls
    class MockClient
      # Mock response object that mimics Faraday::Response
      class MockResponse
        attr_reader :body, :status

        def initialize(body:, status: 200)
          @body = body
          @status = status
        end
      end

      ##
      # Mock implementation of process_document that returns a predefined response
      def process_document(transaction_uuid, _acting_user, _request_data)
        Rails.logger.info("MockClient: Processing document for transaction #{transaction_uuid}")

        MockResponse.new(
          body: mock_response_body,
          status: 200
        )
      end

      private

      ##
      # Returns a simple mock response body as Hash
      # Matches the real API response format after Faraday JSON parsing
      def mock_response_body
        mock_llm_response = {
          doc_type: 'EOB',
          doc_type_matches: true,
          valid: false,
          confidence: 0.9,
          missing_fields: [
            'Provider NPI (10-digit)',
            'Services Paid For (CPT/HCPCS code or description)'
          ],
          present_fields: {
            'Date of Service' => '01/29/13',
            'Provider Name' => 'Smith, Robert',
            'Amount Paid by Insurance' => '0.00'
          },
          notes: 'The document is classified as an EOB. Missing required fields for \'Provider NPI (10-digit)\' and ' \
                 '\'Services Paid For (CPT/HCPCS code or description)\'.'
        }

        # Return as Hash to match Faraday JSON parsing behavior
        {
          'answer' => "```json\n#{JSON.pretty_generate(mock_llm_response)}\n```"
        }
      end
    end
  end
end
