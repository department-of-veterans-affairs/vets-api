# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EwsUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:veteran_id) { '1012667145V762142' }
  let(:loa) { { current: 3, highest: 3 } }
  let(:claim) { create_claim }
  let(:ews) { create(:claims_api_evidence_waiver_submission, :with_full_headers_tamara) }
  let(:claim_id) { claim[:bnft_claim_dto][:bnft_claim_id] }

  context 'when waiver consent is present and allowed' do
    let(:filed5103_waiver_ind) { 'Y' }

    it 'updates evidence waiver record for a qualifying ews submittal' do
      VCR.use_cassette('bgs/benefit_claim/update_bnft_claim') do
        claim[:bnft_claim_dto][:filed5103_waiver_ind] = filed5103_waiver_ind
        ews.claim_id = claim_id
        ews.save
        target_veteran = create_target_veteran
        allow(ClaimsApi::Veteran).to receive(:new).and_return(target_veteran)
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:new).and_return(ews)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:new).and_return(claim)
        allow_any_instance_of(BGS::BenefitClaimWebServiceV1).to receive(:find_bnft_claim).and_return(claim)
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
        claim[:bnft_claim_dto][:filed5103_waiver_ind] = filed5103_waiver_ind
        ews.claim_id = claim_id
        ews.save
        target_veteran = create_target_veteran
        allow(ClaimsApi::Veteran).to receive(:new).and_return(target_veteran)
        allow(ClaimsApi::EvidenceWaiverSubmission).to receive(:new).and_return(ews)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:new).and_return(claim)
        allow_any_instance_of(BGS::BenefitClaimWebServiceV1).to receive(:find_bnft_claim).and_return(claim)
        create_mock_lighthouse_service
        subject.new.perform(ews.id)
        ews.reload

        expect(ews.status).to eq(ClaimsApi::EvidenceWaiverSubmission::UPDATED)
      end
    end
  end

  private

  def create_claim # rubocop:disable Metrics/MethodLength
    {
      bnft_claim_dto:
      {
        bnft_claim_id: '600333346',
        bnft_claim_type_cd: '020CLMINC',
        bnft_claim_type_label: 'Compensation',
        bnft_claim_type_nm: 'Claim for Increase',
        bnft_claim_user_display: 'YES',
        claim_jrsdtn_lctn_id: '123725',
        claim_rcvd_dt: '2022-09-23',
        cp_claim_end_prdct_type_cd: '021',
        jrn_dt: '2022-09-26T11:43:04',
        jrn_lctn_id: '283',
        jrn_obj_id: 'cd_clm_lc_status_pkg.do_create',
        jrn_status_type_cd: 'U',
        jrn_user_id: 'VBMSSYSACCT',
        payee_type_cd: '00',
        payee_type_nm: 'Veteran',
        pgm_type_cd: 'CPL',
        pgm_type_nm: 'Compensation-Pension Live',
        ptcpnt_clmant_id: '600043201',
        ptcpnt_clmant_nm: 'ELLIS TAMARA',
        ptcpnt_mail_addrs_id: '14981239',
        ptcpnt_pymt_addrs_id: '14906550',
        ptcpnt_vet_id: '600043201',
        ptcpnt_vsr_id: '600831201',
        station_of_jurisdiction: '499',
        status_type_cd: 'RFD',
        status_type_nm: 'Ready for Decision',
        submtr_applcn_type_cd: 'VBMS',
        submtr_role_type_cd: 'VBA',
        svc_type_cd: 'CP',
        termnl_digit_nbr: '15'
      },
      "@xmlns:ns0": 'http://benefitclaim.services.vetsnet.vba.va.gov/'
    }
  end

  def create_target_veteran
    {
      mhv_icn: veteran_id,
      loa: loa,
      external_key: 'external_key',
      external_uid: 'external_uid'
    }
  end

  def create_mock_lighthouse_service
    BGS::Services.new(external_uid: 'uid', external_key: 'key').benefit_claims
  end
end
