# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::BD do
  subject { described_class.new }

  before do
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  describe '#upload' do
    let(:claim) { create(:auto_established_claim, evss_id: 600_400_688) }
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-526EZ.pdf' }
    let(:file_number) { '796378782' }
    let(:body) { {} }
    let(:endpoint) { 'documents' }

    it 'uploads a document to BD' do
      VCR.use_cassette('claims_api/bd/upload') do
        result = subject.upload(claim:, pdf_path:)
        expect(result).to be_a Hash
        expect(result[:data][:success]).to be true
      end
    end

    it 'uploads an attachment to BD' do
      result = subject.send(:generate_upload_body, claim:, doc_type: 'L023', original_filename: '21-526EZ.pdf',
                                                   pdf_path:)
      js = JSON.parse(result[:parameters].read)
      expect(js['data']['docType']).to eq 'L023'
    end

    it 'can handle a nil response' do
      allow_any_instance_of(ClaimsApi::BD).to receive(:get_response).with(body, endpoint).and_return(nil)
      result = subject.send(:generate_upload_body, claim:, doc_type: 'L023', original_filename: '21-526EZ.pdf',
                                                   pdf_path:)
      js = JSON.parse(result[:parameters].read)
      expect(js['data']['docType']).to eq 'L023'
    end
  end

  describe '#search', vcr: 'claims_api/v2/claims_show' do
    let(:claim_id) { '600397218' }
    let(:file_number) { '796378782' }
    let(:body) { { data: { claimId: claim_id, fileNumber: file_number } } }
    let(:endpoint) { 'documents/search' }

    it 'locates claim documents when provided a fileNumber and claimId' do
      result = subject.search(claim_id, file_number)

      expect(result).to be_a Hash
      expect(result[:data][:documents]).to be_truthy
    end

    it 'can handle a nil response' do
      allow_any_instance_of(ClaimsApi::BD).to receive(:get_response).with(body, endpoint).and_return(nil)
      result = subject.search(claim_id, file_number)

      expect(result).to eq(nil)
    end
  end
end
