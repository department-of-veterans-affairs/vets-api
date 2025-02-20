# frozen_string_literal: true

require 'rails_helper'
require 'bgs/vnp_benefit_claim'

RSpec.describe BGS::VnpBenefitClaim do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:veteran_hash) do
    {
      vnp_participant_id: participant_id,
      vnp_participant_address_id: '113372'
    }
  end
  let(:vnp_benefit_claim) do
    {
      vnp_proc_id: '3828033',
      vnp_benefit_claim_id: '425718',
      vnp_benefit_claim_type_code: '130DPNEBNADJ',
      claim_jrsdtn_lctn_id: '335',
      intake_jrsdtn_lctn_id: '335',
      participant_claimant_id: '146189'
    }
  end
  let(:benefit_claim) do
    {
      benefit_claim_id: '600196508',
      claim_type_code: '130DPNEBNADJ',
      participant_claimant_id: '600061742',
      program_type_code: 'CPL',
      service_type_code: 'CP',
      status_type_code: 'PEND'
    }
  end

  describe '#create' do
    it 'returns a VnpBenefitClaimObject' do
      VCR.use_cassette('bgs/vnp_benefit_claim/create') do
        vnp_benefit_claim = BGS::VnpBenefitClaim.new(
          proc_id:,
          veteran: veteran_hash,
          user: user_object
        ).create

        expect(vnp_benefit_claim).to include(
          vnp_benefit_claim_id: '425718',
          vnp_benefit_claim_type_code: '130DPNEBNADJ',
          claim_jrsdtn_lctn_id: '335',
          intake_jrsdtn_lctn_id: '335'
        )
      end
    end

    it 'calls BGS::VnpBnftClaimService#vnp_benefit_claim_create' do
      VCR.use_cassette('bgs/vnp_benefit_claim/create') do
        expect_any_instance_of(BGS::VnpBnftClaimService).to receive(:vnp_bnft_claim_create)
          .with(
            a_hash_including(
              pgm_type_cd: 'COMP',
              ptcpnt_clmant_id: '146189',
              ptcpnt_mail_addrs_id: '113372',
              status_type_cd: 'CURR',
              svc_type_cd: 'CP',
              vnp_proc_id: '3828033',
              vnp_ptcpnt_vet_id: '146189'
            )
          )
          .and_call_original

        BGS::VnpBenefitClaim.new(
          proc_id:,
          veteran: veteran_hash,
          user: user_object
        ).create
      end
    end
  end

  describe '#update' do
    it 'updates a VnpBenefitClaimObject' do
      VCR.use_cassette('bgs/vnp_benefit_claim/update') do
        existing_record = BGS::VnpBenefitClaim.new(
          proc_id:,
          veteran: veteran_hash,
          user: user_object
        ).update(benefit_claim, vnp_benefit_claim)

        expect(existing_record).to include(
          vnp_bnft_claim_id: '425718',
          bnft_claim_type_cd: '130DPNEBNADJ',
          claim_jrsdtn_lctn_id: '335',
          intake_jrsdtn_lctn_id: '335',
          bnft_claim_id: '600196508',
          vnp_proc_id: '3828033'
        )
      end
    end

    it 'calls BGS::VnpBnftClaimService#vnp_benefit_claim_create' do
      VCR.use_cassette('bgs/vnp_benefit_claim/update') do
        expect_any_instance_of(BGS::VnpBnftClaimService).to receive(:vnp_bnft_claim_update)
          .with(
            a_hash_including(
              bnft_claim_id: '600196508',
              ptcpnt_clmant_id: '146189',
              vnp_bnft_claim_id: '425718',
              vnp_proc_id: '3828033'
            )
          )
          .and_call_original

        BGS::VnpBenefitClaim.new(
          proc_id:,
          veteran: veteran_hash,
          user: user_object
        ).update(benefit_claim, vnp_benefit_claim)
      end
    end
  end
end
