# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::VnpBenefitClaim do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:user_hash) do
    {
      participant_id: user_object.participant_id,
      ssn: user_object.ssn,
      first_name: user_object.first_name,
      last_name: user_object.last_name,
      external_key: user_object.common_name || user_object.email,
      icn: user_object.icn
    }
  end
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:veteran_hash) do
    {
      vnp_participant_id: participant_id,
      vnp_participant_address_id: '113372'
    }
  end

  describe '#create' do
    it 'returns a VnpBenefitClaimObject' do
      VCR.use_cassette('bgs/vnp_benefit_claim/create') do
        vnp_benefit_claim = BGS::VnpBenefitClaim.new(
          proc_id: proc_id,
          veteran: veteran_hash,
          user: user_hash
        ).create

        expect(vnp_benefit_claim).to include(
          vnp_benefit_claim_id: '425378',
          vnp_benefit_claim_type_code: '130DPNEBNADJ',
          claim_jrsdtn_lctn_id: '335',
          intake_jrsdtn_lctn_id: '335'
        )
      end
    end

    it 'calls BGS::Service#create_benefit_claim' do
      VCR.use_cassette('bgs/vnp_benefit_claim/create') do
        expect_any_instance_of(BGS::Service).to receive(:create_benefit_claim)
          .with(proc_id, veteran_hash)
          .and_call_original

        BGS::VnpBenefitClaim.new(
          proc_id: proc_id,
          veteran: veteran_hash,
          user: user_hash
        ).create
      end
    end
  end
end
