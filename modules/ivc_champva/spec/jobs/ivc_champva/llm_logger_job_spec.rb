# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::LlmLoggerJob do
  let(:form_id) { 'vha_10_10d' }
  let(:uuid) { '123e4567-e89b-12d3-a456-426614174000' }
  let(:attachment_record_id) { 123 }
  let(:attachment_id) { 'test_attachment_123' }
  let(:llm_service) { instance_double(IvcChampva::LlmService) }
  let(:logger) { instance_double(Logger) }
  let(:monitor) { instance_double(IvcChampva::Monitor) }
  let(:mock_file) { double('file', original_filename: 'test.pdf', rewind: true) }
  let(:attachment) do
    instance_double(
      PersistentAttachments::MilitaryRecords,
      id: 123,
      file: mock_file,
      guid: '1234-5678',
      form_id: 'vha_10_10d'
    )
  end

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
    allow(File).to receive(:exist?).and_return(true)
    allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
      .with(id: attachment_record_id)
      .and_return(attachment)
    allow(IvcChampva::LlmService).to receive(:new).and_return(llm_service)
    allow(llm_service).to receive(:process_document).and_return(mock_llm_response)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(logger).to receive(:warn)
    allow(mock_file).to receive(:read).and_return('file content', nil) # It's important to return nil after the content
    allow(Flipper).to receive(:enabled?).with(:champva_enable_llm_on_submit, anything).and_return(true)

    # Mock tempfile creation and PDF conversion
    tempfile = double('tempfile', path: '/tmp/test_file.pdf', close!: true)
    allow(IvcChampva::TempfileHelper).to receive(:tempfile_from_attachment).and_return(tempfile)
    allow(Common::ConvertToPdf).to receive(:new).and_return(double(run: '/tmp/converted.pdf'))

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

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end

      it 'tracks processing time' do
        expect(monitor).to receive(:track_experiment_processing_time).with('llm_validator', anything, uuid)

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end

      it 'tracks LLM response metrics' do
        expect(monitor).to receive(:track_experiment_metric).with('llm_validator', 'confidence', 0.95, uuid)
        expect(monitor).to receive(:track_experiment_metric).with('llm_validator', 'validity', true, uuid)
        expect(monitor).to receive(:track_experiment_metric).with('llm_validator', 'missing_fields_count', 2, uuid)

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end

      it 'logs missing fields count to Rails logger' do
        expect(logger).to receive(:info).with(
          "IvcChampva::LlmLoggerJob #{uuid} missing_fields_count: 2"
        )

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_enable_llm_on_submit, anything).and_return(false)
      end

      it 'does not process document or log anything' do
        expect(llm_service).not_to receive(:process_document)
        expect(logger).not_to receive(:info)
        expect(logger).not_to receive(:error)

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
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

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end
    end

    context 'when LLM response is not a hash' do
      let(:mock_llm_response) { 'invalid response' }

      it 'logs error about unexpected format' do
        expect(logger).to receive(:error).with(
          "IvcChampva::LlmLoggerJob #{uuid} unexpected LLM response format: String"
        )

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end
    end

    context 'when attachment record is not found' do
      before do
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(id: attachment_record_id)
          .and_return(nil)
      end

      it 'logs warning and returns early' do
        expect(logger).to receive(:warn).with(
          "IvcChampva::LlmLoggerJob Attachment record not found for ID: #{attachment_record_id}."
        )
        expect(llm_service).not_to receive(:process_document)

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end
    end

    context 'when attachment has no file data' do
      let(:attachment_without_file) do
        instance_double(
          PersistentAttachments::MilitaryRecords,
          id: 123,
          file: nil,
          guid: '1234-5678',
          form_id: 'vha_10_10d'
        )
      end

      before do
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(id: attachment_record_id)
          .and_return(attachment_without_file)
      end

      it 'logs warning and returns early' do
        expect(logger).to receive(:warn).with(
          "IvcChampva::LlmLoggerJob Attachment #{attachment_record_id} has no file data"
        )
        expect(llm_service).not_to receive(:process_document)

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end
    end

    context 'when PDF file does not exist' do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'raises an error' do
        expect(logger).to receive(:error).with(
          a_string_including('failed with error: No such file or directory - PDF file not found')
        )
        expect(monitor).to receive(:track_experiment_error).with('llm_validator', 'Errno::ENOENT',
                                                                 uuid, 'No such file or directory - PDF file not found')

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end
    end

    context 'when PDF path is nil' do
      before do
        allow(Common::ConvertToPdf).to receive(:new).and_return(double(run: nil))
      end

      it 'raises an error' do
        expect(logger).to receive(:error).with(
          a_string_including('PDF path is nil')
        )
        expect(monitor).to receive(:track_experiment_error).with('llm_validator', 'Errno::ENOENT',
                                                                 uuid, 'No such file or directory - PDF path is nil')

        described_class.new.perform(form_id, uuid, attachment_record_id, attachment_id, 'current_user')
      end
    end
  end
end
