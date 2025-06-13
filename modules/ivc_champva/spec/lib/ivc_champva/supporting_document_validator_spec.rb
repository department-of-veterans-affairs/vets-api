# frozen_string_literal: true

require 'rails_helper'
require 'ivc_champva/supporting_document_validator'

RSpec.describe IvcChampva::SupportingDocumentValidator do
  let(:file_path) { '/path/to/document.pdf' }
  let(:form_uuid) { 'test-form-uuid' }
  let(:attachment_id) { 'Social Security card' }
  let(:validator) { described_class.new(file_path, form_uuid, attachment_id:) }

  describe '#initialize' do
    it 'sets the file path, form uuid, and attachment id' do
      expect(validator.file_path).to eq(file_path)
      expect(validator.form_uuid).to eq(form_uuid)
      expect(validator.attachment_id).to eq(attachment_id)
    end
  end

  describe 'VALIDATOR_MAP' do
    it 'maps attachment IDs to their corresponding validator classes' do
      expected_map = {
        'Explanation of Benefits' => IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator
      }
      expect(described_class::VALIDATOR_MAP).to eq(expected_map)
    end
  end

  describe '#process' do
    let(:validator) { described_class.new(file_path, form_uuid, attachment_id:) }
    let(:mock_validator) { instance_double(IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator) }

    before do
      allow(validator).to receive(:perform_ocr)
      allow(validator).to receive(:extracted_text).and_return('Sample OCR text with EOB information')
    end

    context 'when a direct validator mapping exists' do
      let(:attachment_id) { 'Explanation of Benefits' }

      before do
        allow(IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator)
          .to receive(:new).and_return(mock_validator)

        # Mock the process_and_cache method to return confidence score
        allow(mock_validator).to receive(:process_and_cache)
          .with('Sample OCR text with EOB information').and_return(0.8)
        allow(mock_validator).to receive_messages(
          results_cached?: true,
          cached_validity: true,
          cached_extracted_fields: { provider: 'Test Provider', amount: '100.00' },
          cached_confidence_score: 0.8,
          document_type: 'eob',
          class: IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator
        )
      end

      it 'uses the mapped validator' do
        result = validator.process

        expect(result[:validator_type]).to include('EobTesseractValidator')
        expect(result[:document_type]).to eq('eob')
        expect(result[:is_valid]).to be true
        expect(result[:extracted_fields]).to eq({ provider: 'Test Provider', amount: '100.00' })
        expect(result[:confidence]).to eq(0.8)
      end
    end

    context 'when no direct mapping exists but fallback detection finds a suitable validator' do
      let(:attachment_id) { 'unknown_attachment' }

      before do
        # Mock EOB validator as suitable with high confidence
        allow(IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator)
          .to receive(:new).and_return(mock_validator)
        allow(mock_validator).to receive(:process_and_cache)
          .with('Sample OCR text with EOB information').and_return(0.9)
        allow(mock_validator).to receive_messages(
          cached_validity: true,
          cached_extracted_fields: { provider: 'Test Provider' },
          cached_confidence_score: 0.9,
          document_type: 'eob',
          class: IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator
        )
      end

      it 'selects the validator with the highest confidence score' do
        result = validator.process

        expect(result[:validator_type]).to include('EobTesseractValidator')
        expect(result[:document_type]).to eq('eob')
        expect(result[:confidence]).to eq(0.9)
        expect(result[:extracted_fields]).to eq({ provider: 'Test Provider' })
      end
    end

    context 'when no validator is suitable' do
      let(:attachment_id) { 'unknown_attachment' }

      before do
        # Mock EOB validator to return nil (not suitable)
        allow(IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator)
          .to receive(:new).and_return(mock_validator)
        allow(mock_validator).to receive(:process_and_cache).and_return(nil)
      end

      it 'returns a default result' do
        result = validator.process

        expect(result[:validator_type]).to be_nil
        expect(result[:document_type]).to eq('unknown')
        expect(result[:is_valid]).to be false
        expect(result[:extracted_fields]).to eq({})
        expect(result[:confidence]).to eq(0.0)
      end
    end
  end
end
