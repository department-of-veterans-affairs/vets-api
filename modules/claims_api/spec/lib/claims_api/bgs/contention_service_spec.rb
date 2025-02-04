# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/contention_service'

describe ClaimsApi::ContentionService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  it 'get find_contentions_by_ptcpnt_id' do
    VCR.use_cassette('claims_api/bgs/contention/find_contentions_by_ptcpnt_id') do
      response = subject.find_contentions_by_ptcpnt_id('600036156')
      expect(response[:benefit_claims].count).to eq(383)

      first_claim = response[:benefit_claims].first
      expect(first_claim[:call_id]).to eq('17')
      expect(first_claim[:jrn_lctn_id]).to eq('281')
      expect(first_claim[:jrn_obj_id]).to eq('EBENEFITS  - CEST')
      expect(first_claim[:jrn_stt_tc]).to eq('I')
      expect(first_claim[:jrn_user_id]).to eq('VAEBENEFITS')
      expect(first_claim[:name]).to eq('BenefitClaim')
      expect(first_claim[:row_cnt]).to eq('383')
      expect(first_claim[:row_id]).to eq('8726')
      expect(first_claim[:bnft_clm_tc]).to eq('400SUPP')
      expect(first_claim[:bnft_clm_tn]).to eq('eBenefits 526EZ-Supplemental (400)')
      expect(first_claim[:clm_id]).to eq('600100330')
      expect(first_claim[:clm_suspns_cd]).to eq('056')
      expect(first_claim[:lc_stt_rsn_tc]).to eq('CAN')
      expect(first_claim[:lc_stt_rsn_tn]).to eq('Cancelled')
      expect(first_claim[:lctn_id]).to eq('322')
      expect(first_claim[:non_med_clm_desc]).to eq('eBenefits 526EZ-Supplemental (400)')
      expect(first_claim[:notes_ind]).to eq('1')
      expect(first_claim[:prirty]).to eq('0')
      expect(first_claim[:ptcpnt_id_clmnt]).to eq('600036156')
      expect(first_claim[:ptcpnt_id_vet]).to eq('600036156')
      expect(first_claim[:ptcpnt_suspns_id]).to eq('13381347')
      expect(first_claim[:soj_lctn_id]).to eq('347')
      expect(first_claim[:suspns_rsn_txt]).to eq('Cancelled')
    end
  end

  it 'responds appropriately with invalid options' do
    VCR.use_cassette('claims_api/bgs/contention/invalid_find_contentions_by_ptcpnt_id') do
      expect do
        subject.find_contentions_by_ptcpnt_id('not-an-id')
      end.to raise_error(Common::Exceptions::UnprocessableEntity)
    end
  end
end
