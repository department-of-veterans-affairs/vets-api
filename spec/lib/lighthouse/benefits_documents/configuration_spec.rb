# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/configuration'

RSpec.describe BenefitsDocuments::Configuration do
  let(:document_data) do
    { file_number: '796378881',
      claim_id: 600_423_040,
      tracked_item_id: [],
      document_type: 'L023',
      file_name: 'doctors-note.pdf' }
  end
  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }

  before do
    token = 'abcd1234'
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#service_name' do
    it 'has the expected service name' do
      VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200') do
        response = BenefitsDocuments::Configuration.instance.post(file_body, document_data)
        expect(response.status).to eq(200)
        expect(response.body).to eq({ 'data' => { 'success' => true, 'requestId' => 74 } })
      end
    end
  end
end
