# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EwsUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
    ews.claim_id = '600065431'
    ews.save
  end

  let(:veteran_id) { '1012667145V762142' }
  let(:ews) { create(:claims_api_evidence_waiver_submission, :with_full_headers_tamara) }

  context 'when waiver consent is present and allowed' do
    it 'updates evidence waiver record for a qualifying ews submittal' do
      VCR.use_cassette('bgs/benefit_claim/update_5103_claim') do
        subject.new.perform(ews.id)
        ews.reload

        expect(ews.status).to eq(ClaimsApi::EvidenceWaiverSubmission::PENDING)
      end
    end
  end
end
