# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/configuration'

RSpec.describe BenefitsDocuments::Configuration do
  before do
    # Required to prevent inconsistent failure on CI pipeline
    Flipper.enable('va_online_scheduling')

    token = 'abcd1234'
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return(token)
  end

  describe 'BenefitsDocuments Configuration' do
    context 'when file is pdf' do
      let(:document_data) do
        { file_number: '796378881',
          claim_id: '600423040',
          tracked_item_id: nil,
          document_type: 'L023',
          file_name: 'doctors-note.pdf' }
      end
      let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }

      it 'uploads expected document' do
        VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200_pdf') do
          response = BenefitsDocuments::Configuration.instance.post(file_body, document_data)
          expect(response.status).to eq(200)
          expect(response.body).to eq({ 'data' => { 'success' => true, 'requestId' => 74 } })
        end
      end
    end

    context 'when file is jpg' do
      let(:document_data) do
        { file_number: '796378881',
          claim_id: '600423040',
          tracked_item_id: nil,
          document_type: 'L023',
          file_name: 'doctors-note.jpg' }
      end
      let(:file_body) { File.read(fixture_file_upload('doctors-note.jpg', 'image/jpeg')) }

      it 'uploads expected document' do
        VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200_jpg') do
          response = BenefitsDocuments::Configuration.instance.post(file_body, document_data)
          expect(response.status).to eq(200)
          expect(response.body).to eq({ 'data' => { 'success' => true, 'requestId' => 153 } })
        end
      end
    end
  end
end
