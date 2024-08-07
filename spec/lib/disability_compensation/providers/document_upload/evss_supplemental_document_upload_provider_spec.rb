# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/document_upload/evss_supplemental_document_upload_provider'
require 'support/disability_compensation_form/shared_examples/supplemental_document_upload_provider'

RSpec.describe EVSSSupplementalDocumentUploadProvider do
  let(:submission) { create(:form526_submission) }
  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }
  let(:file_name) { Faker::File.file_name }

  let(:provider) do
    EVSSSupplementalDocumentUploadProvider.new(
      submission,
      file_body
    )
  end

  let(:evss_claim_document) do
    EVSSClaimDocument.new(
      evss_claim_id: submission.submitted_claim_id,
      document_type: 'L023',
      file_name:
    )
  end

  it_behaves_like 'supplemental document upload provider'

  describe '#generate_upload_document' do
    it 'generates an EVSSClaimDocument' do
      file_name = Faker::File.file_name
      document_type = 'L023'

      upload_document = provider.generate_upload_document(file_name, document_type)

      expect(upload_document).to be_an_instance_of(EVSSClaimDocument)
      expect(upload_document).to have_attributes(
        {
          evss_claim_id: submission.submitted_claim_id,
          file_name:,
          document_type:
        }
      )
    end
  end

  describe '#validate_upload_document' do
    context 'when the document is a valid EVSSClaimDocument' do
      it 'returns true' do
        expect(provider.validate_upload_document(evss_claim_document)).to eq(true)
      end
    end

    context 'when the document is an invalid EVSSClaimDocument' do
      it 'returns false' do
        allow_any_instance_of(EVSSClaimDocument).to receive(:valid?).and_return(false)
        expect(provider.validate_upload_document(evss_claim_document)).to eq(false)
      end
    end
  end

  describe '#submit_upload_document' do
    context 'for a valid payload' do
      let(:faraday_response) { instance_double(Faraday::Response) }

      it 'submits the document via the EVSSDocumentService and returns the API response' do
        allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
          .with(file_body, evss_claim_document)
          .and_return(faraday_response)

        expect(provider.submit_upload_document(evss_claim_document)).to eq(faraday_response)
      end
    end
  end
end
