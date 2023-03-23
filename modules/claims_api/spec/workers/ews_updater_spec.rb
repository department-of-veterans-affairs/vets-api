# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EwsUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:veteran_id) { '1012667145V762142' }
  let(:loa) { { current: 3, highest: 3 } }
  let(:bgs_res) { build(:bgs_response).to_h }
  let(:ews) { create(:claims_api_evidence_waiver_submission, :with_full_headers_tamara) }
  let(:claim_id) { bgs_res[:bnft_claim_dto][:bnft_claim_id] }

  context 'when waiver consent is present and allowed' do
    let(:filed5103_waiver_ind) { 'Y' }

    it 'updates evidence waiver record for a qualifying ews submittal' do
      VCR.use_cassette('bgs/benefit_claim/update_bnft_claim') do
        bgs_res[:bnft_claim_dto][:filed5103_waiver_ind] = filed5103_waiver_ind
        ews.claim_id = claim_id
        ews.save
        target_veteran = create_target_veteran
        allow(ClaimsApi::Veteran).to receive(:new).and_return(target_veteran)
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:new).and_return(ews)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:new).and_return(bgs_res)
        allow_any_instance_of(BGS::BenefitClaimWebServiceV1).to receive(:find_bnft_claim).and_return(bgs_res)
        create_mock_lighthouse_service
        subject.new.perform(ews.id)
        ews.reload

        expect(ews.status).to eq(ClaimsApi::EvidenceWaiverSubmission::UPDATED)
      end
    end
  end

  context 'when waiver consent is not present' do
    let(:filed5103_waiver_ind) { 'N' }

    it 'updates evidence waiver record for a qualifying ews submittal' do
      VCR.use_cassette('bgs/benefit_claim/update_bnft_claim') do
        bgs_res[:bnft_claim_dto][:filed5103_waiver_ind] = filed5103_waiver_ind
        ews.claim_id = claim_id
        ews.save
        target_veteran = create_target_veteran
        allow(ClaimsApi::Veteran).to receive(:new).and_return(target_veteran)
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:new).and_return(ews)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:new).and_return(bgs_res)
        allow_any_instance_of(BGS::BenefitClaimWebServiceV1).to receive(:find_bnft_claim).and_return(bgs_res)
        create_mock_lighthouse_service
        subject.new.perform(ews.id)
        ews.reload

        expect(ews.status).to eq(ClaimsApi::EvidenceWaiverSubmission::UPDATED)
      end
    end
  end

  private

  def create_target_veteran
    {
      mhv_icn: veteran_id,
      loa:,
      external_key: 'external_key',
      external_uid: 'external_uid'
    }
  end

  def create_mock_lighthouse_service
    BGS::Services.new(external_uid: 'uid', external_key: 'key').benefit_claims
  end
end
