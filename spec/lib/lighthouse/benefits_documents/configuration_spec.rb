# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/configuration'

RSpec.describe BenefitsDocuments::Configuration do
  before do
    # Required to prevent inconsistent failure on CI pipeline
    Flipper.enable('va_online_scheduling') # rubocop:disable Project/ForbidFlipperToggleInSpecs

    token = 'abcd1234'
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return(token)
  end

  describe 'BenefitsDocuments Configuration' do
    let(:document_data) do
      OpenStruct.new(
        participant_id: '796378881',
        claim_id: '600423040',
        tracked_item_id: nil,
        document_type: 'L023',
        file_name: 'doctors-note.jpg'
      )
    end

    describe '#post' do
      context 'when file is pdf' do
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

    describe '#claimant_can_upload_document' do
      context 'when the claimant can upload a document' do
        it 'returns a 200 response with valid=true' do
          VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_validate_claimant_success') do
            response = BenefitsDocuments::Configuration.instance.claimant_can_upload_document(document_data)
            expect(response.status).to eq(200)
            expect(response.body['data']['valid']).to be(true)
          end
        end
      end

      context 'when the claimant cannot upload a document' do
        let(:document_data) do
          OpenStruct.new(
            participant_id: '796378882', # intentionally one off
            claim_id: '600423040',
            tracked_item_id: nil,
            document_type: 'L023',
            file_name: 'doctors-note.jpg'
          )
        end

        it 'returns a 200 response with valid=false' do
          VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_validate_claimant_failure') do
            response = BenefitsDocuments::Configuration.instance.claimant_can_upload_document(document_data)
            expect(response.status).to eq(200)
            expect(response.body['data']['valid']).to be(false)
          end
        end
      end
    end
  end
end
