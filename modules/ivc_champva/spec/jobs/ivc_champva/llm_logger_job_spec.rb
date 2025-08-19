# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::LlmLoggerJob do
  let(:form_id) { 'vha_10_10d' }
  let(:uuid) { '123e4567-e89b-12d3-a456-426614174000' }
  let(:file_path) { 'spec/fixtures/files/test.pdf' }
  let(:attachment_id) { 'test_attachment_123' }
  let(:llm_service) { instance_double(IvcChampva::LlmService) }
  let(:logger) { instance_double(Logger) }
  let(:monitor) { instance_double(IvcChampva::Monitor) }

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

    # Mock the monitor and its methods
    allow(IvcChampva::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_experiment_sample_size)
    allow(monitor).to receive(:track_experiment_processing_time)
    allow(monitor).to receive(:track_experiment_metric)
    allow(monitor).to receive(:track_experiment_error)
  end

  describe '#perform' do
    context 'when feature flag is enabled' do
      it 'tracks experiment sample size' do
        expect(monitor).to receive(:track_experiment_sample_size).with('llm_validator', uuid)

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end

      it 'tracks processing time' do
        expect(monitor).to receive(:track_experiment_processing_time).with('llm_validator', anything, uuid)

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end

      it 'tracks LLM response metrics' do
        expect(monitor).to receive(:track_experiment_metric).with('llm_validator', 'confidence', 0.95, uuid)
        expect(monitor).to receive(:track_experiment_metric).with('llm_validator', 'validity', true, uuid)
        expect(monitor).to receive(:track_experiment_metric).with('llm_validator', 'missing_fields_count', 2, uuid)

        described_class.new.perform(form_id, uuid, file_path, attachment_id)
      end

      it 'logs missing fields count to Rails logger' do
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

      it 'logs the error and tracks it' do
        expect(logger).to receive(:error).with(
          "IvcChampva::LlmLoggerJob #{uuid} failed with error: Test error"
        )
        expect(monitor).to receive(:track_experiment_error).with('llm_validator', 'StandardError', uuid, 'Test error')

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
