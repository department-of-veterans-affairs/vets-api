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

    it 'uploads a document to BD' do
      VCR.use_cassette('bd/upload') do
        result = subject.upload(claim:, pdf_path:)
        expect(result).to be_a Hash
        expect(result[:data][:success]).to be true
      end
    end

    it 'uploads an attachment to BD' do
      result = subject.send(:generate_upload_body, claim:, doc_type: 'L023', pdf_path:)
      js = JSON.parse(result[:parameters].read)
      expect(js['data']['docType']).to eq 'L023'
    end
  end

  describe '#search', vcr: 'claims_api/v2/claims_show' do
    let(:claim_id) { '600397218' }
    let(:file_number) { '796378782' }

    it 'locates claim documents when provided a fileNumber and claimId' do
      result = subject.search(claim_id, file_number)

      expect(result).to be_a Hash
      expect(result[:data][:documents]).to be_truthy
    end
  end
end
