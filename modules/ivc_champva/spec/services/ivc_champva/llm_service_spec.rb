# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::LlmService do
  let(:service) { described_class.new }
  let(:form_id) { 'vha_10_10d' }
  let(:file_path) { 'spec/fixtures/files/test.pdf' }
  let(:uuid) { '123e4567-e89b-12d3-a456-426614174000' }
  let(:attachment_id) { 'test_attachment_123' }
  let(:prompt) { 'Please analyze this document.' }
  let(:llm_client) { instance_double(IvcChampva::LlmProcessorApi::Client) }

  let(:mock_llm_response) do
    # the following JSON is a real response from the LLM processor API with a fake document - no PII
    double(
      'Response',
      status: 200,
      body: {
        answer: '```json
{
  "doc_type": "EOB",
  "doc_type_matches": true,
  "valid": false,
  "confidence": 0.9,
  "missing_fields": ["Provider NPI (10-digit)", "Services Paid For (CPT/HCPCS code or description)"],
  "present_fields": {
    "Date of Service": "01/29/13",
    "Provider Name": "Smith, Robert",
    "Amount Paid by Insurance": "0.00"
  },
  "notes": "The document is classified as an EOB. Missing required fields for Provider NPI and Services Paid For."
}
```'
      }.to_json
    )
  end

  before do
    # Mock file existence check more flexibly
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(file_path).and_return(true)

    # Mock the prompt manager
    allow(IvcChampva::PromptManager).to receive(:get_prompt).and_return(prompt)

    # Mock the LLM client
    allow(IvcChampva::LlmProcessorApi::Client).to receive(:new).and_return(llm_client)
    allow(llm_client).to receive(:process_document).and_return(mock_llm_response)
  end

  describe '#process_document' do
    context 'when file exists and LLM processing succeeds' do
      it 'returns parsed LLM response' do
        result = service.process_document(
          form_id:,
          file_path:,
          uuid:,
          attachment_id:
        )

        expect(result).to include(
          'doc_type' => 'EOB',
          'doc_type_matches' => true,
          'valid' => false,
          'confidence' => 0.9,
          'missing_fields' => ['Provider NPI (10-digit)', 'Services Paid For (CPT/HCPCS code or description)']
        )
        expect(result['present_fields']).to be_a(Hash)
        expect(result['notes']).to be_a(String)
      end

      it 'calls LLM client with correct parameters' do
        expect(llm_client).to receive(:process_document).with(
          uuid,
          'llm_service',
          {
            prompt:,
            file_path:,
            form_id:,
            uuid:,
            attachment_id:
          }
        )

        service.process_document(
          form_id:,
          file_path:,
          uuid:,
          attachment_id:
        )
      end
    end

    context 'when file does not exist' do
      before do
        allow(File).to receive(:exist?).with(file_path).and_return(false)
      end

      it 'raises ENOENT error' do
        expect do
          service.process_document(
            form_id:,
            file_path:,
            uuid:,
            attachment_id:
          )
        end.to raise_error(Errno::ENOENT, /File not found/)
      end
    end

    context 'when LLM response is malformed' do
      let(:mock_llm_response) do
        double(
          'Response',
          status: 200,
          body: 'Invalid JSON'
        )
      end

      it 'returns empty hash' do
        result = service.process_document(
          form_id:,
          file_path:,
          uuid:,
          attachment_id:
        )

        expect(result).to eq({})
      end
    end

    context 'when LLM response contains invalid JSON in answer' do
      let(:mock_llm_response) do
        double(
          'Response',
          status: 200,
          body: { answer: 'Invalid JSON' }.to_json
        )
      end

      it 'returns empty hash' do
        result = service.process_document(
          form_id:,
          file_path:,
          uuid:,
          attachment_id:
        )

        expect(result).to eq({})
      end
    end
  end
end
