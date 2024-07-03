# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::BD do
  subject { described_class.new }

  let(:ews) do
    create(:claims_api_evidence_waiver_submission, :with_full_headers_jesse, claim_id: '60897890')
  end.freeze
  let(:claim) { create(:auto_established_claim, evss_id: 600_400_688, id: '581128c6-ad08-4b1e-8b82-c3640e829fb3') }

  before do
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  describe 'disability comp (doc_type: L122), and other attachments (doc_type: L023)' do
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-526EZ.pdf' }

    describe '#upload' do
      it 'uploads a document to BD' do
        VCR.use_cassette('claims_api/bd/upload') do
          result = subject.upload(claim:, pdf_path:)
          expect(result).to be_a Hash
          expect(result[:data][:success]).to be true
        end
      end

      it 'uploads an attachment to BD for L023' do
        result = subject.send(:generate_upload_body, claim:, doc_type: 'L023', pdf_path:,
                                                     original_filename: 'stuff.pdf')
        js = JSON.parse(result[:parameters].read)
        expect(js['data']['docType']).to eq 'L023'
      end

      it 'uploads an attachment to BD for L122' do
        result = subject.send(:generate_upload_body, claim:, doc_type: 'L122', original_filename: '21-526EZ.pdf',
                                                     pdf_path:)
        js = JSON.parse(result[:parameters].read)
        expect(js['data']['docType']).to eq 'L122'
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

    describe '#build_body' do
      it 'builds an L122 (526) body correctly' do
        result = subject.send(:build_body, doc_type: 'L122', file_name: '21-526EZ.pdf', claim_id: claim.id)

        expected = { data: { systemName: 'VA.gov', docType: 'L122', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                             fileName: '21-526EZ.pdf', trackedItemIds: [] } }
        expect(result).to eq(expected)
      end

      it 'builds an L023 (corespondence) body correctly' do
        result = subject.send(:build_body, doc_type: 'L023', file_name: 'rx.pdf', claim_id: claim.id)

        expected = { data: { systemName: 'VA.gov', docType: 'L023', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                             fileName: 'rx.pdf', trackedItemIds: [] } }
        expect(result).to eq(expected)
      end
    end
  end

  describe 'evidence waiver submissions (doc_type: L705)' do
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/5103.pdf' }

    describe '#generate_upload_body' do
      it 'uploads an attachment to BD for L705' do
        result = subject.send(:generate_upload_body, claim: ews, doc_type: 'L705', original_filename: '5103.pdf',
                                                     pdf_path:)
        js = JSON.parse(result[:parameters].read)
        expect(js['data']['docType']).to eq 'L705'
      end
    end

    describe '#build_body' do
      it 'builds an L705 (5103) body correctly' do
        result = subject.send(:build_body, doc_type: 'L705', file_name: '5103.pdf', claim_id: ews.claim_id)

        expected = { data: { systemName: 'VA.gov', docType: 'L705', claimId: '60897890',
                             fileName: '5103.pdf', trackedItemIds: [] } }
        expect(result).to eq(expected)
      end

      it 'builds an L705 (5103) body with all of the params correctly' do
        result = subject.send(:build_body, doc_type: 'L705', file_name: '5103.pdf', claim_id: ews.claim_id,
                                           tracked_item_ids: [234, 235], participant_id: '60289076',
                                           file_number: '7348296')

        expected = { data: { systemName: 'VA.gov', docType: 'L705', claimId: '60897890',
                             fileName: '5103.pdf', trackedItemIds: [234, 235], participantId: '60289076',
                             fileNumber: '7348296' } }
        expect(result).to eq(expected)
      end
    end
  end
end
