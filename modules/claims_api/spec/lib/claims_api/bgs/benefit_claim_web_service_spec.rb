# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/benefit_claim_web_service'

describe ClaimsApi::BenefitClaimWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:claim_id) { '600100330' }

  describe '#find_bnft_claim' do
    it 'updates a benefit claim' do
      VCR.use_cassette('claims_api/bgs/benefit_claim_web_service/find_bnft_claim') do
        result = subject.find_bnft_claim(claim_id:)

        expect(result).to be_a Hash
        expect(result[:bnft_claim_dto][:bnft_claim_id]).to eq('600100330')
        expect(result[:bnft_claim_dto][:bnft_claim_type_label]).to eq('Compensation')
      end
    end
  end

  describe '#update_bnft_claim' do
    let(:claim) do
      {
        bnft_claim_dto: { bnft_claim_id: '600100330',
                          bnft_claim_type_cd: '400SUPP',
                          bnft_claim_type_label: 'Compensation',
                          bnft_claim_type_nm: 'eBenefits 526EZ-Supplemental (400)',
                          bnft_claim_user_display: 'YES',
                          claim_jrsdtn_lctn_id: '322',
                          claim_rcvd_dt: '2017-04-24T00:00:00-05:00',
                          claim_suspns_dt: '2017-05-24T10:54:20-05:00',
                          cp_claim_end_prdct_type_cd: '409',
                          jrn_dt: '2021-03-02T13:55:18-06:00',
                          jrn_lctn_id: '281',
                          jrn_obj_id: 'cd_clm_ptcpnt_pkg.do_create',
                          jrn_status_type_cd: 'U',
                          jrn_user_id: 'VAgovAPI',
                          payee_type_cd: '00',
                          payee_type_nm: 'Veteran',
                          pgm_type_cd: 'CPL',
                          pgm_type_nm: 'Compensation-Pension Live',
                          ptcpnt_clmant_id: '600036156',
                          ptcpnt_clmant_nm: 'BROOKS JERRY',
                          ptcpnt_dposit_acnt_id: '56960',
                          ptcpnt_mail_addrs_id: '15125513',
                          ptcpnt_vet_id: '600036156',
                          ptcpnt_vsr_id: '600276939',
                          scrty_level_type_cd: '5',
                          station_of_jurisdiction: '281',
                          status_type_cd: 'CAN',
                          status_type_nm: 'Cancelled',
                          svc_type_cd: 'CP',
                          temp_jrsdtn_lctn_id: '359',
                          temporary_station_of_jurisdiction: '330',
                          termnl_digit_nbr: '37' }
      }
    end

    it 'updates a benefit claim' do
      VCR.use_cassette('claims_api/bgs/benefit_claim_web_service/update_bnft_claim') do
        res = subject.update_bnft_claim(claim:)

        expect(res).to be_a Hash
        expect(res[:bnft_claim_dto][:bnft_claim_id]).to eq('600100330')
      end
    end
  end

  describe '#find_bnft_claim_by_clmant_id' do
    context 'when given the correct arguments' do
      let(:dependent_participant_id) { '600036156' }

      it 'returns a successful response' do
        VCR.use_cassette('claims_api/bgs/benefit_claim_web_service/servie_spec') do
          res = subject.find_bnft_claim_by_clmant_id(dependent_participant_id:)

          expect(res).to be_a Hash
          expect(res[:bnft_claim_dto][0][:bnft_claim_id]).to eq('600596284')
          expect(res[:bnft_claim_dto].count).to eq(2)
        end
      end
    end
  end
end
