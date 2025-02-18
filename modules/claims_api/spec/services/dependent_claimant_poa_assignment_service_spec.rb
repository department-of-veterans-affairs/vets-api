# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/local_bgs'

Rspec.describe ClaimsApi::DependentClaimantPoaAssignmentService do
  describe '#assign_poa_to_dependent!' do
    let(:dependent_participant_id) { '600052700' }
    let(:service) do
      described_class.new(poa_code: '002', veteran_participant_id: '600052699', dependent_participant_id:,
                          veteran_file_number: '796163671', claimant_ssn: '796163672')
    end
    let(:mock_find_benefit_claims_status_by_ptcpnt_id) do
      {
        benefit_claims_dto:
        { benefit_claim:
        [{
          appeal_possible: 'No',
          attention_needed: 'Yes',
          base_end_prdct_type_cd: '690',
          benefit_claim_id: '256009',
          bnft_claim_type_cd: '690AUTRWPMC',
          claim_dt: '2013-03-01',
          claim_status: 'RDC',
          claim_status_type: 'Authorization Review',
          decision_notification_sent: 'No',
          development_letter_sent: 'Yes',
          ealiest_evidence_due_date: '2024-08-25',
          end_prdct_type_cd: '691',
          filed5103_waiver_ind: 'Y',
          latest_evidence_recd_date: '2015-09-18',
          max_est_claim_complete_dt: '2013-03-30',
          min_est_claim_complete_dt: '2013-03-28',
          phase_chngd_dt: '2013-03-26T06:24:43',
          phase_type: 'Pending Decision Approval',
          program_type: 'CPD',
          ptcpnt_clmant_id: '600052700',
          ptcpnt_vet_id: '600052699'
        }] }
      }
    end
    let(:mock_find_bnft_claim) do
      {
        bnft_claim_dto:
          {
            bnft_claim_id: '256009',
            bnft_claim_type_cd: '690AUTRWPMC',
            bnft_claim_type_label: 'Authorization Review',
            bnft_claim_type_nm: 'PMC-Reviews - Authorization Only',
            bnft_claim_user_display: 'YES',
            claim_jrsdtn_lctn_id: '347',
            claim_rcvd_dt: '2013-03-01T00:00:00-06:00',
            claim_suspns_dt: '2024-08-20T12:09:48-05:00',
            cp_claim_end_prdct_type_cd: '691',
            filed5103_waiver_ind: 'Y',
            jrn_dt: '2024-10-01T11:58:31-05:00',
            jrn_lctn_id: '281',
            jrn_obj_id: 'VAgovAPI',
            jrn_status_type_cd: 'U',
            jrn_user_id: 'VAgovAPI',
            payee_type_cd: '10',
            payee_type_nm: 'Spouse',
            pgm_type_cd: 'CPD',
            pgm_type_nm: 'Compensation-Pension Death',
            ptcpnt_clmant_id: '600052700',
            ptcpnt_clmant_nm: 'CURTIS MARGIE',
            ptcpnt_mail_addrs_id: '16542930',
            ptcpnt_pymt_addrs_id: '14781119',
            ptcpnt_vet_id: '600052699',
            station_of_jurisdiction: '317',
            status_type_cd: 'RDC',
            status_type_nm: 'Rating Decision Complete',
            svc_type_cd: 'CP',
            temp_jrsdtn_lctn_id: '123725',
            temporary_station_of_jurisdiction: '499',
            termnl_digit_nbr: '71'
          }
      }
    end
    let(:mock_update_benefit_claim) do
      {
        return:
          { benefit_claim_record: {
              pre_dschrg_type_cd: nil
            },
            life_cycle_record: nil,
            participant_record: nil,
            return_code: 'GUIE05000',
            return_message: 'Update to Corporate was successful',
            suspence_record: nil }
      }
    end

    context 'when the dependent has no open claims' do
      it 'assigns the POA to the dependent via manage_ptcpnt_rlnshp' do
        VCR.use_cassette('claims_api/bgs/person_web_service/manage_ptcpnt_rlnshp_poa_no_open_claims') do
          VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
            allow(service).to receive(:assign_poa_to_dependent_via_manage_ptcpnt_rlnshp?).and_call_original

            expect do
              service.assign_poa_to_dependent!
            end.not_to raise_error

            expect(service).to have_received(:assign_poa_to_dependent_via_manage_ptcpnt_rlnshp?)
          end
        end
      end
    end

    context 'when the dependent has open claims' do
      it 'assigns the POA to the dependent via update_benefit_claim' do
        VCR.use_cassette('claims_api/bgs/person_web_service/manage_ptcpnt_rlnshp_poa_with_open_claims') do
          VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
            allow(service).to receive(:assign_poa_to_dependent_via_update_benefit_claim?).and_call_original
            allow_any_instance_of(ClaimsApi::EbenefitsBnftClaimStatusWebService).to receive(
              :find_benefit_claims_status_by_ptcpnt_id
            )
              .with(dependent_participant_id).and_return(mock_find_benefit_claims_status_by_ptcpnt_id)
            allow_any_instance_of(ClaimsApi::BenefitClaimWebService).to receive(:find_bnft_claim)
              .with(claim_id: '256009').and_return(mock_find_bnft_claim)
            allow_any_instance_of(ClaimsApi::BenefitClaimService).to receive(:update_benefit_claim)
              .and_return(mock_update_benefit_claim)

            expect do
              service.assign_poa_to_dependent!
            end.not_to raise_error

            expect(service).to have_received(:assign_poa_to_dependent_via_update_benefit_claim?)
          end
        end
      end
    end

    describe '#bgs_claim_status_service' do
      it 'requires the service statement' do
        res = service.send(:bgs_claim_status_service)
        expect(res).to be_a(ClaimsApi::EbenefitsBnftClaimStatusWebService)
      end
    end

    describe '#benefit_claim_web_service' do
      it 'requires the service statement' do
        res = service.send(:benefit_claim_web_service)
        expect(res).to be_a(ClaimsApi::BenefitClaimWebService)
      end
    end

    describe '#benefit_claim_service' do
      it 'requires the service statement' do
        res = service.send(:benefit_claim_service)
        expect(res).to be_a(ClaimsApi::BenefitClaimService)
      end
    end

    describe '#person_web_service' do
      it 'requires the service statement' do
        res = service.send(:person_web_service)
        expect(res).to be_a(ClaimsApi::PersonWebService)
      end
    end
  end
end
