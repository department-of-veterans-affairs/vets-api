# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::LlmLoggerJob do
  let(:form_id) { 'vha_10_10d' }
  let(:uuid) { '123e4567-e89b-12d3-a456-426614174000' }
  let(:file_path) { 'spec/fixtures/files/test.pdf' }
  let(:attachment_id) { 'test_attachment_123' }
  let(:llm_service) { instance_double(IvcChampva::LlmService) }
  let(:logger) { instance_double(Logger) }

  let(:mock_llm_response) do
    {
      'doc_type' => 'EOB',
      'doc_type_matches' => true,
      'valid' => true,
      'confidence' => 0.95,
      'missing_fields' => %w[field1 field2]
    }
  end

  before do
    allow(Rails).to receive(:logger).and_return(logger)
    allow(IvcChampva::LlmService).to receive(:new).and_return(llm_service)
    allow(llm_service).to receive(:process_document).and_return(mock_llm_response)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(Flipper).to receive(:enabled?).with(:champva_enable_llm_on_submit).and_return(true)
  end

  describe '#perform' do
    context 'when feature flag is enabled' do
      it 'logs job start' do
        expect(logger).to receive(:info).with(
          "IvcChampva::LlmLoggerJob Beginning job for form_id: #{form_id}, uuid: #{uuid}"
        )

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end

      it 'logs processing time' do
        expect(logger).to receive(:info).with(
          /IvcChampva::LlmLoggerJob #{uuid} LLM processing completed in \d+\.\d+ milliseconds/
        )

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end

      it 'logs LLM response fields' do
        expect(logger).to receive(:info).with(
          "IvcChampva::LlmLoggerJob #{uuid} doc_type: EOB"
        )
        expect(logger).to receive(:info).with(
          "IvcChampva::LlmLoggerJob #{uuid} doc_type_matches: true"
        )
        expect(logger).to receive(:info).with(
          "IvcChampva::LlmLoggerJob #{uuid} valid: true"
        )
        expect(logger).to receive(:info).with(
          "IvcChampva::LlmLoggerJob #{uuid} confidence: 0.95"
        )
        expect(logger).to receive(:info).with(
          "IvcChampva::LlmLoggerJob #{uuid} missing_fields_count: 2"
        )

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_enable_llm_on_submit).and_return(false)
      end

      it 'does not process document or log anything' do
        expect(llm_service).not_to receive(:process_document)
        expect(logger).not_to receive(:info)
        expect(logger).not_to receive(:error)

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end
    end

    context 'when LLM service raises an error' do
      before do
        allow(llm_service).to receive(:process_document).and_raise(StandardError.new('Test error'))
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with(
          "IvcChampva::LlmLoggerJob #{uuid} failed with error: Test error"
        )

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end
    end

    context 'when LLM response is not a hash' do
      let(:mock_llm_response) { 'invalid response' }

      it 'logs error about unexpected format' do
        expect(logger).to receive(:error).with(
          "IvcChampva::LlmLoggerJob #{uuid} unexpected LLM response format: String"
        )

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end
    end
  end
end
