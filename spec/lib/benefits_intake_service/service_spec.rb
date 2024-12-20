# frozen_string_literal: true

require 'rails_helper'
require 'benefits_intake_service/service'

RSpec.describe BenefitsIntakeService::Service do
  let(:job) { described_class.new }

  describe 'generate_metadata' do
    it 'submits metadata with invalid characters and validates' do
      metadata = {
        veteran_first_name: 'te`st',
        veteran_last_name: 'last name',
        file_number: '987654321',
        zip: '20007',
        source: 'va.gov backup submission',
        doc_type: '686C-674',
        business_line: 'CMP',
        claim_date: Date.new(2024, 7, 31)
      }

      expected_response = {
        'veteranFirstName' => 'test',
        'veteranLastName' => 'last name',
        'fileNumber' => '987654321',
        'zipCode' => '20007',
        'source' => 'va.gov backup submission',
        'docType' => '686C-674',
        'businessLine' => 'CMP',
        'claimDate' => Date.new(2024, 7, 31)
      }
      expect(job.generate_metadata(metadata)).to eq(expected_response)
    end
  end

  describe 'valid_document?' do
    let(:validator) { double('validator') }
    let(:validator_response) { double('validator_response') }
    let(:response) { double('response') }
    let(:document) { 'random/path/to/pdf' }

    before do
      allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(validator)
      allow(validator).to receive(:validate).and_return(validator_response)
      allow(job).to receive(:validate_document).and_return(response)
    end

    it 'returns a pdf path' do
      allow(validator_response).to receive(:valid_pdf?).and_return(true)
      allow(response).to receive(:success?).and_return(true)
      expect(job.valid_document?(document:)).to eq(document)
    end

    it 'raises an error for invalid pdf validation' do
      allow(validator_response).to receive_messages(valid_pdf?: false,
                                                    errors: 'Maximum page size exceeded. Limit is 78 in x 101 in.')
      expect { job.valid_document?(document:) }.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
    end

    it 'raises an error for invalid Lighthouse validation' do
      allow(validator_response).to receive_messages(valid_pdf?: true)
      allow(response).to receive(:success?).and_return(false)
      expect { job.valid_document?(document:) }.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
    end
  end
end
