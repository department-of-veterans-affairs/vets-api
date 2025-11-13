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

  describe '#upload_doc' do
    let(:upload_url)  { 'https://example.com/s3-upload-url' }
    let(:metadata)    { { doc_type: '21-526EZ' } }
    let(:main_file)   { 'main.pdf' }
    let(:attachments) { [{ file: 'attach-a.pdf' }, { file: 'attach-b.pdf' }] }

    before do
      allow(job).to receive(:get_file_path_from_objs) do |arg|
        case arg
        when Hash then arg[:file]
        else arg
        end
      end

      allow(job).to receive(:get_upload_docs)
        .and_return([{ dummy: true }, instance_double(Tempfile)])

      allow(job).to receive(:upload_deletion_logic)
    end

    context 'when all documents are valid' do
      it 'validates main and each attachment, then performs the PUT and returns the response' do
        allow(job).to receive(:validate_if_pdf).and_return(true)

        success_response = double('response', success?: true, body: '{}')
        expect(job).to receive(:perform)
          .with(:put, upload_url, kind_of(Hash), hash_including('Content-Type' => 'multipart/form-data'))
          .and_return(success_response)

        result = job.upload_doc(upload_url:, file: main_file, metadata:, attachments:)
        expect(result).to eq(success_response)

        expect(job).to have_received(:validate_if_pdf).with(main_file)
        expect(job).to have_received(:validate_if_pdf).with('attach-a.pdf')
        expect(job).to have_received(:validate_if_pdf).with('attach-b.pdf')
      end
    end

    context 'when the main document is invalid' do
      it 'raises InvalidDocumentError and does not perform the PUT' do
        allow(job).to receive(:validate_if_pdf)
          .with(main_file)
          .and_raise(BenefitsIntakeService::Service::InvalidDocumentError)

        expect(job).not_to receive(:perform).with(:put, anything, anything, anything)

        expect do
          job.upload_doc(upload_url:, file: main_file, metadata:, attachments: [])
        end.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
      end
    end

    context 'when an attachment is invalid' do
      it 'raises InvalidDocumentError and does not perform the PUT' do
        allow(job).to receive(:validate_if_pdf).with(main_file).and_return(true)
        allow(job).to receive(:validate_if_pdf)
          .with('attach-a.pdf')
          .and_raise(BenefitsIntakeService::Service::InvalidDocumentError)

        expect(job).not_to receive(:perform).with(:put, anything, anything, anything)

        expect do
          job.upload_doc(upload_url:, file: main_file, metadata:, attachments:)
        end.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
      end
    end

    context 'when the remote upload returns non-success' do
      it 'raises the response body' do
        failure_response = double('response', success?: false, body: 'upload failed')
        allow(job).to receive_messages(validate_if_pdf: true, perform: failure_response)

        expect do
          job.upload_doc(upload_url:, file: main_file, metadata:, attachments: [])
        end.to raise_error('upload failed')
      end
    end
  end
end
