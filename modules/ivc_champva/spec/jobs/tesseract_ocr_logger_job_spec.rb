# frozen_string_literal: true

require 'rails_helper'
require 'ivc_champva/supporting_document_validator'

RSpec.describe IvcChampva::TesseractOcrLoggerJob, type: :job do
  let(:job) { described_class.new }
  let(:validator) { instance_double(IvcChampva::SupportingDocumentValidator) }

  extracted_fields = { ssn: '123-45-6789', name: 'John Doe', age: 42 }
  result = {
    validator_type: 'the validator type',
    document_type: 'the document type',
    is_valid: true,
    confidence: 0.8675309,
    extracted_fields: extracted_fields
  }

  before do
    allow(File).to receive(:exist?).and_return(true)
    allow(IvcChampva::SupportingDocumentValidator).to receive(:new).and_return(validator)
    allow(validator).to receive(:process).and_return(result)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when champva_enable_ocr_on_submit is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit).and_return(false)
      end

      it 'does not perform OCR validation' do
        job.perform('form_id', 'uuid', 'file_path', 'attachment_id')
        expect(validator).not_to have_received(:process)
        expect(Rails.logger).not_to have_received(:info).with(a_string_including('Beginning job for'))
      end
    end

    context 'when champva_enable_ocr_on_submit is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit).and_return(true)
      end

      it 'performs OCR validation' do
        job.perform('form_id', 'uuid', 'file_path', 'attachment_id')
        expect(validator).to have_received(:process).once
      end

      it 'logs validator results' do
        job.perform('form_id', 'uuid', 'file_path', 'attachment_id')
        expect(Rails.logger).to have_received(:info).with(a_string_including('the validator type'))
        expect(Rails.logger).to have_received(:info).with(a_string_including('the document type'))
        expect(Rails.logger).to have_received(:info).with(a_string_including('is_valid: true'))
        expect(Rails.logger).to have_received(:info).with(a_string_including('0.8675309'))
        expect(Rails.logger).to have_received(:info).with(a_string_including('ssn: type=String, length=11'))
        expect(Rails.logger).to have_received(:info).with(a_string_including('name: type=String, length=8'))
        expect(Rails.logger).to have_received(:info).with(a_string_including('age: type=Integer'))
      end

      it 'does not log values from extracted fields which may contain PII' do
        job.perform('form_id', 'uuid', 'file_path', 'attachment_id')
        extracted_fields.values.each do |value|
          expect(Rails.logger).not_to have_received(:info).with(a_string_including(value.to_s))
        end
      end

      it 'raises an error if the file does not exist' do
        allow(File).to receive(:exist?).and_return(false)

        job.perform('form_id', 'uuid', 'file_path', 'attachment_id')
        expect(Rails.logger).to have_received(:error).with(a_string_including('failed with error: No such file or directory - File not found'))
        expect(Rails.logger).not_to have_received(:error).with(a_string_including('file_path')) # path may contain PII
      end
    end
  end

end
