# frozen_string_literal: true

require 'rails_helper'
require 'ivc_champva/supporting_document_validator'

RSpec.describe 'EobTesseractValidator', type: :integration do
  let(:sample_eob_pdf) { Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'files', 'SampleEOB.pdf') }
  let(:attachment_id) { 'Unknown Document Type' } # Use unknown type to test auto-detection
  let(:validator) do
    IvcChampva::SupportingDocumentValidator.new(sample_eob_pdf, 'test-form-uuid', attachment_id:)
  end

  before do
    # Ensure the test file exists
    expect(sample_eob_pdf).to exist
  end

  describe 'document auto-detection' do
    it 'automatically identifies the SampleEOB.pdf as an EOB document' do
      result = validator.process

      # Should auto-detect as EOB document
      expect(result[:validator_type]).to eq(
        'IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator'
      )
      expect(result[:document_type]).to eq('explanation_of_benefits')
      expect(result[:attachment_id]).to eq('Unknown Document Type')
    end

    it 'processes the SampleEOB.pdf and extracts relevant fields' do
      result = validator.process

      # Verify basic result structure
      expect(result).to include(:validator_type, :document_type, :attachment_id, :is_valid, :extracted_fields,
                                :confidence)

      # Check extracted_fields contents
      expect(result[:extracted_fields]).to eq(
        {
          date_of_service: '03/21/13',
          provider_name: 'Smith, Robert Claim',
          npi: nil,
          service_code: '14221',
          amount_paid: '1000.00'
        }
      )

      # Since this is a sample EOB with fixed data we should always get a confidence score of just over 0.6
      expect(result[:confidence]).to be > 0.6
      expect(result[:confidence]).to be < 0.601
    end

    context 'with unknown attachment_id variations' do
      ['Unknown', 'Some Other Document', nil].each do |unknown_id|
        it "works with attachment_id: #{unknown_id.inspect}" do
          test_validator = IvcChampva::SupportingDocumentValidator.new(
            sample_eob_pdf,
            'test-form-uuid',
            attachment_id: unknown_id
          )
          result = test_validator.process

          # Should still detect as EOB
          expect(result[:validator_type]).to eq(
            'IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator'
          )
        end
      end
    end
  end

  describe 'end-to-end document processing' do
    it 'handles the complete OCR and validation pipeline' do
      result = validator.process

      # Verify the correct validator was used
      expect(result[:validator_type]).to eq(
        'IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator'
      )
      expect(result[:document_type]).to eq('explanation_of_benefits')
      expect(result[:attachment_id]).to eq('Unknown Document Type')

      # Check field extraction
      fields = result[:extracted_fields]
      expect(fields).to be_a(Hash)
      expect(fields.keys).to include(:date_of_service, :provider_name, :npi, :service_code, :amount_paid)

      # Verify confidence scoring
      expect(result[:confidence]).to be_a(Float)
      expect(result[:confidence]).to be >= 0.0
      expect(result[:confidence]).to be <= 1.0

      # Document validity (may be false if required fields are missing)
      expect(result[:is_valid]).to be_in([true, false])
    end

    context 'confidence scoring' do
      it 'calculates confidence based on found fields' do
        result = validator.process
        confidence = result[:confidence]

        # Base confidence should be at least 0.2 if recognized as EOB
        if result[:validator_type] == 'IvcChampva::DocumentOcrValidators::Tesseract::EobTesseractValidator'
          expect(confidence).to be >= 0.2
        end
      end
    end
  end

  describe 'PDF processing' do
    it 'successfully converts PDF to image for OCR processing' do
      # This tests the complete pipeline including PDF conversion
      expect { validator.process }.not_to raise_error
    end
  end

  describe 'error handling' do
    context 'with corrupted file' do
      let(:bad_file) { Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'files', 'nonexistent.pdf') }
      let(:bad_validator) do
        IvcChampva::SupportingDocumentValidator.new(bad_file, 'test-form-uuid', attachment_id:)
      end

      it 'handles missing files gracefully' do
        expect { bad_validator.process }.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe 'field extraction accuracy' do
    it 'extracts expected fields from SampleEOB.pdf' do
      result = validator.process
      fields = result[:extracted_fields]

      # These are fields we expect to find in most EOBs
      found_fields = fields.select { |_key, value| !value.nil? && !value.to_s.empty? }
      expect(found_fields.keys).to include(:date_of_service, :provider_name, :service_code, :amount_paid)
    end
  end
end
