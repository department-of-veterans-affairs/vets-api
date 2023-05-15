# frozen_string_literal: true

require 'claims_api/special_issue_mappers/bgs'

FactoryBot.define do
  factory :auto_established_claim, class: 'ClaimsApi::AutoEstablishedClaim' do
    id { SecureRandom.uuid }
    status { 'pending' }
    source { 'oddball' }
    evss_id { nil }
    auth_headers { { test: ('a'..'z').to_a.shuffle.join } }
    form_data do
      json = JSON.parse(File
             .read(::Rails.root.join(*'/modules/claims_api/spec/fixtures/form_526_json_api.json'.split('/')).to_s))
      json['data']['attributes']
    end
    flashes { form_data.dig('veteran', 'flashes') }
    special_issues do
      if form_data['disabilities'].present? && form_data['disabilities'].first['specialIssues'].present?
        mapper = ClaimsApi::SpecialIssueMappers::Bgs.new
        [{ code: form_data['disabilities'].first['diagnosticCode'],
           name: form_data['disabilities'].first['name'],
           special_issues: form_data['disabilities'].first['specialIssues'].map { |si| mapper.code_from_name!(si) } }]
      else
        []
      end
    end

    trait :status_established do
      status { 'established' }
      evss_id { 600_118_851 }
    end

    trait :status_errored do
      status { 'errored' }
      evss_response { 'something' }
    end

    trait :autoCestPDFGeneration_disabled do
      form_data do
        json = JSON.parse(File
               .read(::Rails.root.join(*'/modules/claims_api/spec/fixtures/form_526_json_api.json'.split('/'))
               .to_s))
        json['data']['attributes']['autoCestPDFGenerationDisabled'] = false
        json['data']['attributes']
      end
    end

    factory :auto_established_claim_with_supporting_documents do
      after(:create) do |auto_established_claim|
        create_list(:supporting_document, 1, auto_established_claim:)
      end
    end
  end

  factory :auto_established_claim_without_flashes_or_special_issues, class: 'ClaimsApi::AutoEstablishedClaim' do
    id { SecureRandom.uuid }
    status { 'pending' }
    source { 'oddball' }
    evss_id { nil }
    auth_headers { { test: ('a'..'z').to_a.shuffle.join } }
    form_data do
      # rubocop:disable Layout/LineLength
      json = JSON.parse(File
             .read(::Rails.root.join(*'/modules/claims_api/spec/fixtures/form_526_no_flashes_no_special_issues.json'.split('/')).to_s))
      json['data']['attributes']
    end
    # rubocop:enable Layout/LineLength

    trait :status_errored do
      status { 'errored' }
      evss_response { 'something' }
    end
  end

  factory :auto_established_claim_with_auth_headers, class: 'ClaimsApi::AutoEstablishedClaim' do
    id { SecureRandom.uuid }
    status { 'pending' }
    source { 'oddball' }
    evss_id { nil }
    auth_headers { { va_eauth_pnid: '123456789', va_eauth_pid: '123456789' } }
    form_data do
      json = JSON.parse(File
             .read(::Rails.root.join(*'/modules/claims_api/spec/fixtures/form_526_json_api.json'.split('/')).to_s))
      json['data']['attributes']
    end
    flashes { form_data.dig('veteran', 'flashes') }
    special_issues do
      if form_data['disabilities'].present? && form_data['disabilities'].first['specialIssues'].present?
        mapper = ClaimsApi::SpecialIssueMappers::Bgs.new
        [{ code: form_data['disabilities'].first['diagnosticCode'],
           name: form_data['disabilities'].first['name'],
           special_issues: form_data['disabilities'].first['specialIssues'].map { |si| mapper.code_from_name!(si) } }]
      else
        []
      end
    end
  end

  factory :bgs_response, class: OpenStruct do
    bnft_claim_dto { (association :benefit_claim_details_dto).to_h }
  end

  factory :benefit_claim_details_dto, class: OpenStruct do
    bnft_claim_id { Faker::Number.number(digits: 9) }
    bnft_claim_type_cd { Faker::Alphanumeric.alpha(number: 9) }
    bnft_claim_type_label { 'Compensation' }
    bnft_claim_type_nm { 'Claim for Increase' }
    bnft_claim_user_display { 'YES' }
    claim_jrsdtn_lctn_id { Faker::Number.number(digits: 6) }
    claim_rcvd_dt { Faker::Date.backward(days: 90) }
    cp_claim_end_prdct_type_cd { Faker::Number.number(digits: 3) }
    jrn_dt { Faker::Time.backward(days: 5, period: :morning) }
    jrn_lctn_id { Faker::Number.number(digits: 3) }
    jrn_obj_id { 'cd_clm_lc_status_pkg.do_create' }
    jrn_status_type_cd { 'U' }
    jrn_user_id { 'VBMSSYSACCT' }
    payee_type_cd { Faker::Number.number(digits: 2) }
    payee_type_nm { 'Veteran' }
    pgm_type_cd { 'CPL' }
    pgm_type_nm { 'Compensation-Pension Live' }
    ptcpnt_clmant_id { Faker::Number.number(digits: 9) }
    ptcpnt_clmant_nm { Faker::Name.name }
    ptcpnt_mail_addrs_id { Faker::Number.number(digits: 8) }
    ptcpnt_pymt_addrs_id { Faker::Number.number(digits: 8) }
    ptcpnt_vet_id { Faker::Number.number(digits: 9) }
    ptcpnt_vsr_id { Faker::Number.number(digits: 9) }
    station_of_jurisdiction { Faker::Number.number(digits: 3) }
    status_type_cd { 'RFD' }
    status_type_nm { 'Ready for Decision' }
    submtr_applcn_type_cd { 'VBMS' }
    submtr_role_type_cd { 'VBA' }
    svc_type_cd { 'CP' }
    termnl_digit_nbr { Faker::Number.number(digits: 2) }
    filed5103_waiver_ind { 'Y' }
  end
  factory :bgs_response_with_one_lc_status, class: OpenStruct do
    benefit_claim_details_dto { (association :bgs_claim_details_dto_with_one_lc_status).to_h }
  end
  factory :bgs_response_with_lc_status, class: OpenStruct do
    benefit_claim_details_dto { (association :bgs_claim_details_dto_with_lc_status).to_h }
  end
  factory :bgs_response_with_under_review_lc_status, class: OpenStruct do
    benefit_claim_details_dto { (association :bgs_claim_details_dto_with_under_review_lc_status).to_h }
  end
  factory :bgs_response_with_phaseback_lc_status, class: OpenStruct do
    benefit_claim_details_dto { (association :bgs_claim_details_dto_with_phaseback_lc_status).to_h }
  end
  factory :bgs_response_claim_with_unmatched_ptcpnt_vet_id, class: OpenStruct do
    benefit_claim_details_dto {
      (association :bgs_claim_details_with_unmatched_vet_id).to_h
    }
  end
  factory :bgs_claim_details_dto_with_under_review_lc_status, class: OpenStruct do
    benefit_claim_id { '111111111' }
    phase_chngd_dt { Faker::Time.backward(days: 5, period: :morning) }
    phase_type { 'Under Review' }
    ptcpnt_clmant_id { Faker::Number.number(digits: 17) }
    ptcpnt_vet_id { Faker::Number.number(digits: 17) }
    phase_type_change_ind { '76' }
    claim_status_type { 'Compensation' }
    bnft_claim_lc_status { [(association :bnft_claim_lc_status_two).to_h] }
  end
  factory :bgs_claim_details_dto_with_one_lc_status, class: OpenStruct do
    benefit_claim_id { '111111111' }
    phase_chngd_dt { Faker::Time.backward(days: 5, period: :morning) }
    phase_type { 'Pending Decision Approval' }
    ptcpnt_clmant_id { Faker::Number.number(digits: 17) }
    ptcpnt_vet_id { Faker::Number.number(digits: 17) }
    phase_type_change_ind { '76' }
    claim_status_type { 'Compensation' }
    bnft_claim_lc_status { [(association :bnft_claim_lc_status_one).to_h] }
  end
  factory :bgs_claim_details_dto_with_lc_status, class: OpenStruct do
    benefit_claim_id { '111111111' }
    phase_chngd_dt { Faker::Time.backward(days: 5, period: :morning) }
    phase_type { 'Pending Decision Approval' }
    ptcpnt_clmant_id { Faker::Number.number(digits: 17) }
    ptcpnt_vet_id { Faker::Number.number(digits: 17) }
    phase_type_change_ind { '76' }
    claim_complete_dt { Faker::Time.backward(days: 3, period: :morning) }
    claim_status_type { 'Compensation' }
    bnft_claim_lc_status {
      [(association :bnft_claim_lc_status_five).to_h, (association :bnft_claim_lc_status_four).to_h,
       (association :bnft_claim_lc_status_three).to_h, (association :bnft_claim_lc_status_two).to_h,
       (association :bnft_claim_lc_status_one).to_h]
    }
  end
  factory :bgs_claim_details_dto_with_phaseback_lc_status, class: OpenStruct do
    benefit_claim_id { '111111111' }
    phase_chngd_dt { Faker::Time.backward(days: 5, period: :morning) }
    ptcpnt_clmant_id { Faker::Number.number(digits: 17) }
    ptcpnt_vet_id { Faker::Number.number(digits: 17) }
    claim_status_type { 'Compensation' }
    bnft_claim_lc_status { [(association :bnft_claim_lc_status_phaseback).to_h] }
  end
  factory :bnft_claim_lc_status_one, class: OpenStruct do
    max_est_claim_complete_dt { Faker::Time.backward(days: 5, period: :morning) }
    min_est_claim_complete_dt { Faker::Time.backward(days: 7, period: :morning) }
    phase_chngd_dt { Faker::Time.backward(days: 6, period: :morning) }
    phase_type { 'Claim Received' }
    phase_type_change_ind { 'N' }
  end
  factory :bnft_claim_lc_status_two, class: OpenStruct do
    max_est_claim_complete_dt { Faker::Time.backward(days: 5, period: :morning) }
    min_est_claim_complete_dt { Faker::Time.backward(days: 7, period: :morning) }
    phase_chngd_dt { Faker::Time.backward(days: 6, period: :morning) }
    phase_type { 'Under Review' }
    phase_type_change_ind { '12' }
  end
  factory :bnft_claim_lc_status_three, class: OpenStruct do
    max_est_claim_complete_dt { Faker::Time.backward(days: 5, period: :morning) }
    min_est_claim_complete_dt { Faker::Time.backward(days: 7, period: :morning) }
    phase_chngd_dt { Faker::Time.backward(days: 6, period: :morning) }
    phase_type { 'Gathering of Evidence' }
    phase_type_change_ind { '23' }
  end
  factory :bnft_claim_lc_status_four, class: OpenStruct do
    max_est_claim_complete_dt { Faker::Time.backward(days: 5, period: :morning) }
    min_est_claim_complete_dt { Faker::Time.backward(days: 7, period: :morning) }
    phase_chngd_dt { Faker::Time.backward(days: 6, period: :morning) }
    phase_type { 'Review of Evidence' }
    phase_type_change_ind { '34' }
  end
  factory :bnft_claim_lc_status_five, class: OpenStruct do
    max_est_claim_complete_dt { Faker::Time.backward(days: 5, period: :morning) }
    min_est_claim_complete_dt { Faker::Time.backward(days: 7, period: :morning) }
    phase_chngd_dt { Faker::Time.backward(days: 6, period: :morning) }
    phase_type { 'Preparation for Decision' }
    phase_type_change_ind { '45' }
  end
  factory :bnft_claim_lc_status_phaseback, class: OpenStruct do
    max_est_claim_complete_dt { Faker::Time.backward(days: 5, period: :morning) }
    min_est_claim_complete_dt { Faker::Time.backward(days: 7, period: :morning) }
    phase_chngd_dt { Faker::Time.backward(days: 6, period: :morning) }
    phase_type { 'Under Review' }
    phase_type_change_ind { '32' }
  end
  factory :bgs_claim_details_with_unmatched_vet_id, class: OpenStruct do
    benefit_claim_id { '111111111' }
    phase_chngd_dt { Faker::Time.backward(days: 5, period: :morning) }
    phase_type { 'Pending Decision Approval' }
    phase_type_change_ind { '76' }
    ptcpnt_vet_id { Faker::Number.number(digits: 9) }
    ptcpnt_clmant_id { '8675309' }
    claim_status_type { 'Compensation' }
    bnft_claim_lc_status { [(association :bnft_claim_lc_status_one).to_h] }
  end
end
