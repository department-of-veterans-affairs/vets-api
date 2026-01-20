# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::VnpBenefitClaim do
  let(:veteran) do
    {
      vnp_participant_id: '146189',
      vnp_participant_address_id: '113372',
      participant_claimant_id: '600061742',
      benefit_claim_type_end_product: '032312395'
    }
  end

  let(:benefit_claim) { described_class.new('3828033', veteran) }
  let(:create_params_output) do
    {
      vnp_proc_id: '3828033', ptcpnt_clmant_id: '146189', ptcpnt_mail_addrs_id: '113372', vnp_ptcpnt_vet_id: '146189'
    }
  end
  let(:update_params_output) do
    {
      vnp_proc_id: '3828033',
      vnp_bnft_claim_id: '425718',
      bnft_claim_type_cd: '130DPNEBNADJ',
      end_prdct_type_cd: '032312395',
      bnft_claim_id: '600196508',
      vnp_ptcpnt_vet_id: '146189',
      ptcpnt_clmant_id: '146189',
      status_type_cd: 'PEND'
    }
  end
  let(:vnp_benefit_claim_update_param) do
    {
      vnp_proc_id: '3828033',
      vnp_benefit_claim_id: '425718',
      vnp_benefit_claim_type_code: '130DPNEBNADJ',
      claim_jrsdtn_lctn_id: '335',
      intake_jrsdtn_lctn_id: '335',
      participant_claimant_id: '146189'
    }
  end
  let(:benefit_claim_record) do
    {
      benefit_claim_id: '600196508',
      claim_type_code: '130DPNEBNADJ',
      program_type_code: 'CPL',
      service_type_code: 'CP',
      status_type_code: 'PEND'
    }
  end
  let(:response_output) do
    {
      vnp_proc_id: '3828033',
      vnp_benefit_claim_id: '425718',
      vnp_benefit_claim_type_code: '130DPNEBNADJ',
      claim_jrsdtn_lctn_id: '335',
      intake_jrsdtn_lctn_id: '335',
      participant_claimant_id: '146189'
    }
  end
  let(:vnp_benefit_claim_response_param) do
    {
      vnp_bnft_claim_id: '425718',
      bnft_claim_type_cd: '130DPNEBNADJ',
      claim_jrsdtn_lctn_id: '335',
      intake_jrsdtn_lctn_id: '335',
      jrn_lctn_id: '281',
      jrn_obj_id: 'VAgovAPI',
      jrn_status_type_cd: 'U',
      jrn_user_id: 'VAgovAPI',
      pgm_type_cd: 'COMP',
      ptcpnt_clmant_id: '146189',
      vnp_ptcpnt_vet_id: '146189',
      vnp_proc_id: '3828033'
    }
  end

  describe '#create_params_for_686c' do
    it 'creates params for submission to BGS for 686c' do
      create_params = benefit_claim.create_params_for_686c

      expect(create_params).to include(create_params_output)
    end
  end

  describe '#update_params_for_686c' do
    it 'creates update params for submission to BGS for 686c' do
      update_params = benefit_claim.update_params_for_686c(vnp_benefit_claim_update_param, benefit_claim_record)

      expect(update_params).to include(update_params_output)
    end
  end

  describe '#vnp_benefit_claim_response' do
    it 'creates update params for submission to BGS for 686c' do
      response = benefit_claim.vnp_benefit_claim_response(vnp_benefit_claim_response_param)

      expect(response).to include(response_output)
    end
  end
end
