# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::LlmService do
  let(:service) { described_class.new }
  let(:form_id) { 'vha_10_10d' }
  let(:file_path) { 'spec/fixtures/files/test.pdf' }
  let(:uuid) { '123e4567-e89b-12d3-a456-426614174000' }
  let(:attachment_id) { 'test_attachment_123' }
  let(:prompt) { 'Please analyze this document.' }

  before do
    # Mock file existence check more flexibly
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(file_path).and_return(true)

    # Mock the prompt manager
    allow(IvcChampva::PromptManager).to receive(:get_prompt).and_return(prompt)
  end

  describe '#process_document' do
    context 'when file exists and LLM processing succeeds' do
      it 'returns parsed LLM response using mock client in test environment' do
        result = service.process_document(
          form_id:,
          file_path:,
          uuid:,
          attachment_id:
        )

        # Expect the mock client response (EOB document)
        expect(result).to include(
          'doc_type' => 'EOB',
          'doc_type_matches' => true,
          'valid' => false,
          'confidence' => 0.9,
          'missing_fields' => ['Provider NPI (10-digit)', 'Services Paid For (CPT/HCPCS code or description)']
        )
        expect(result['present_fields']).to be_a(Hash)
        expect(result['present_fields']).to include(
          'Date of Service' => '01/29/13',
          'Provider Name' => 'Smith, Robert',
          'Amount Paid by Insurance' => '0.00'
        )
        expect(result['notes']).to be_a(String)
      end

      it 'uses mock client in test environment' do
        # Verify that the service is using the MockClient instead of the real client
        expect(service.instance_variable_get(:@llm_client)).to be_a(IvcChampva::LlmProcessorApi::MockClient)
      end
    end

    context 'environment-based client selection' do
      it 'uses MockClient in test environment' do
        expect(Rails.env).to eq('test')
        expect(service.instance_variable_get(:@llm_client)).to be_a(IvcChampva::LlmProcessorApi::MockClient)
      end

      it 'uses real Client in production environment' do
        allow(Rails).to receive(:env).and_return('production')
        production_service = described_class.new
        expect(production_service.instance_variable_get(:@llm_client)).to be_a(IvcChampva::LlmProcessorApi::Client)
      end

      it 'uses real Client in staging environment' do
        allow(Rails).to receive(:env).and_return('staging')
        staging_service = described_class.new
        expect(staging_service.instance_variable_get(:@llm_client)).to be_a(IvcChampva::LlmProcessorApi::Client)
      end

      it 'uses MockClient in development environment' do
        allow(Rails).to receive(:env).and_return('development')
        dev_service = described_class.new
        expect(dev_service.instance_variable_get(:@llm_client)).to be_a(IvcChampva::LlmProcessorApi::MockClient)
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
  end
end
