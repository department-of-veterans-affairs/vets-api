# frozen_string_literal: true

FactoryBot.define do
  factory :claims_api_evss_claim, class: 'ClaimsApi::EVSSClaim' do
    evss_id { 600_354_181 }

    data {
      {
        'appeal_possible' => 'Yes',
        'attention_needed' => 'No',
        'base_end_prdct_type_cd' => '165',
        'benefit_claim_id' => '600354181',
        'bnft_claim_type_cd' => '165ACRDPMC',
        'claim_close_dt' => '2022-12-20',
        'claim_complete_dt' => '2022-12-20',
        'claim_dt' => '2022-12-20',
        'claim_status' => 'CAN',
        'claim_status_type' => 'Compensation',
        'decision_notification_sent' => 'No',
        'development_letter_sent' => 'No',
        'end_prdct_type_cd' => '165',
        'phase_chngd_dt' => '2022-12-20',
        'phase_type' => 'Complete',
        'program_type' => 'CPD',
        'ptcpnt_clmant_id' => '600836358',
        'ptcpnt_vet_id' => '600061742',
        'contention_list' => [],
        'va_representative' => nil,
        'decision_letter_sent' => 'No',
        'documents_needed' => false,
        'waiver5103_submitted' => false,
        'requested_decision' => false,
        'claim_type' => 'CAN',
        'date' => '12/20/2022',
        'min_est_claim_date' => nil,
        'max_est_claim_date' => nil,
        'claim_phase_dates' => {},
        'status_type' => 'Compensation',
        'status' => 'Complete',
        'open' => false,
        'claim_complete_date' => '12/20/2022'
      }
    }

    list_data {
      {
        'appeal_possible' => 'Yes',
        'attention_needed' => 'No',
        'base_end_prdct_type_cd' => '165',
        'benefit_claim_id' => '600354181',
        'bnft_claim_type_cd' => '165ACRDPMC',
        'claim_close_dt' => '2022-12-20',
        'claim_complete_dt' => '2022-12-20',
        'claim_dt' => '2022-12-20',
        'claim_status' => 'CAN',
        'claim_status_type' => 'Compensation',
        'decision_notification_sent' => 'No',
        'development_letter_sent' => 'No',
        'end_prdct_type_cd' => '165',
        'phase_chngd_dt' => '2022-12-20',
        'phase_type' => 'Complete',
        'program_type' => 'CPD',
        'ptcpnt_clmant_id' => '600836358',
        'ptcpnt_vet_id' => '600061742',
        'contention_list' => [],
        'va_representative' => nil,
        'decision_letter_sent' => 'No',
        'documents_needed' => false,
        'waiver5103_submitted' => false,
        'requested_decision' => false,
        'claim_type' => 'CAN',
        'date' => '12/20/2022',
        'min_est_claim_date' => nil,
        'max_est_claim_date' => nil,
        'claim_phase_dates' => {},
        'status_type' => 'Compensation',
        'status' => 'Complete',
        'open' => false,
        'claim_complete_date' => '12/20/2022'
      }
    }
  end
end
