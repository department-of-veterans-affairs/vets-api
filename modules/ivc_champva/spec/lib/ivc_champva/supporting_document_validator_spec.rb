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
        'EOB' => IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator,
        'medical invoice' => IvcChampva::DocumentOcrValidators::Tesseract::SuperbillTesseractValidator,
        'pharmacy invoice' => IvcChampva::DocumentOcrValidators::Tesseract::PharmacyClaimTesseractValidator
      }
      expect(described_class::VALIDATOR_MAP).to eq(expected_map)
    end
  end

  describe '#process' do
    let(:validator) { described_class.new(file_path, form_uuid, attachment_id:) }
    let(:mock_ssn_validator) do
      instance_double(IvcChampva::DocumentOcrValidators::Tesseract::SocialSecurityCardTesseractValidator)
    end
    let(:mock_eob_validator) { instance_double(IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator) }
    let(:mock_superbill_validator) do
      instance_double(IvcChampva::DocumentOcrValidators::Tesseract::SuperbillTesseractValidator)
    end
    let(:mock_pharmacy_validator) do
      instance_double(IvcChampva::DocumentOcrValidators::Tesseract::PharmacyClaimTesseractValidator)
    end

    before do
      allow(validator).to receive(:perform_ocr)
      allow(validator).to receive(:extracted_text).and_return('Sample OCR text')
    end

    context 'when a direct validator mapping exists for EOB' do
      let(:attachment_id) { 'EOB' }

      before do
        allow(IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator)
          .to receive(:new).and_return(mock_eob_validator)
        allow(mock_eob_validator).to receive(:process_and_cache).with('Sample OCR text').and_return(0.9)
        allow(mock_eob_validator).to receive_messages(
          results_cached?: true,
          cached_validity: true,
          cached_extracted_fields: { provider: 'Test Provider', amount: '100.00' },
          cached_confidence_score: 0.9,
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
        expect(result[:confidence]).to eq(0.9)
      end
    end

    context 'when a direct validator mapping exists for Superbill' do
      let(:attachment_id) { 'Superbill' }

      before do
        allow(IvcChampva::DocumentOcrValidators::Tesseract::SuperbillTesseractValidator)
          .to receive(:new).and_return(mock_superbill_validator)
        allow(mock_superbill_validator).to receive(:process_and_cache).with('Sample OCR text').and_return(0.7)
        allow(mock_superbill_validator).to receive_messages(
          results_cached?: true,
          cached_validity: true,
          cached_extracted_fields: { patient_name: 'Jane Doe', provider_name: 'Dr. Smith' },
          cached_confidence_score: 0.7,
          document_type: 'superbill',
          class: IvcChampva::DocumentOcrValidators::Tesseract::SuperbillTesseractValidator
        )
      end

      it 'uses the mapped validator' do
        result = validator.process
        expect(result[:validator_type]).to include('SuperbillTesseractValidator')
        expect(result[:document_type]).to eq('superbill')
        expect(result[:is_valid]).to be true
        expect(result[:extracted_fields]).to eq({ patient_name: 'Jane Doe', provider_name: 'Dr. Smith' })
        expect(result[:confidence]).to eq(0.7)
      end
    end

    context 'when a direct validator mapping exists for Pharmacy Claim' do
      let(:attachment_id) { 'Pharmacy Claim' }

      before do
        allow(IvcChampva::DocumentOcrValidators::Tesseract::PharmacyClaimTesseractValidator)
          .to receive(:new).and_return(mock_pharmacy_validator)
        allow(mock_pharmacy_validator).to receive(:process_and_cache).with('Sample OCR text').and_return(0.6)
        allow(mock_pharmacy_validator).to receive_messages(
          results_cached?: true,
          cached_validity: true,
          cached_extracted_fields: { patient_name: 'John Doe', rx_number: 'RX123' },
          cached_confidence_score: 0.6,
          document_type: 'pharmacy_claim',
          class: IvcChampva::DocumentOcrValidators::Tesseract::PharmacyClaimTesseractValidator
        )
      end

      it 'uses the mapped validator' do
        result = validator.process
        expect(result[:validator_type]).to include('PharmacyClaimTesseractValidator')
        expect(result[:document_type]).to eq('pharmacy_claim')
        expect(result[:is_valid]).to be true
        expect(result[:extracted_fields]).to eq({ patient_name: 'John Doe', rx_number: 'RX123' })
        expect(result[:confidence]).to eq(0.6)
      end
    end

    context 'when no validator is suitable' do
      let(:attachment_id) { 'unknown_attachment' }

      before do
        allow(IvcChampva::DocumentOcrValidators::Tesseract::SocialSecurityCardTesseractValidator)
          .to receive(:new).and_return(mock_ssn_validator)
        allow(IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator)
          .to receive(:new).and_return(mock_eob_validator)
        allow(IvcChampva::DocumentOcrValidators::Tesseract::SuperbillTesseractValidator)
          .to receive(:new).and_return(mock_superbill_validator)
        allow(IvcChampva::DocumentOcrValidators::Tesseract::PharmacyClaimTesseractValidator)
          .to receive(:new).and_return(mock_pharmacy_validator)
        allow(mock_ssn_validator).to receive(:process_and_cache).and_return(nil)
        allow(mock_eob_validator).to receive(:process_and_cache).and_return(nil)
        allow(mock_superbill_validator).to receive(:process_and_cache).and_return(nil)
        allow(mock_pharmacy_validator).to receive(:process_and_cache).and_return(nil)
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
