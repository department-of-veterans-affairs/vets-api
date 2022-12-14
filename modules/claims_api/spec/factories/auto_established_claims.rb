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
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_json_api.json"))
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
        json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_json_api.json"))
        json['data']['attributes']['autoCestPDFGenerationDisabled'] = false
        json['data']['attributes']
      end
    end

    factory :auto_established_claim_with_supporting_documents do
      after(:create) do |auto_established_claim|
        create_list(:supporting_document, 1, auto_established_claim: auto_established_claim)
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
      json = JSON.parse(File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_no_flashes_no_special_issues.json"))
      json['data']['attributes']
    end
    # rubocop:enable Layout/LineLength

    trait :status_errored do
      status { 'errored' }
      evss_response { 'something' }
    end
  end

  factory :bgs_response, class: OpenStruct do
    bnft_claim_dto { (association :bnft_claim_dto).to_h }
  end

  factory :bnft_claim_dto, class: OpenStruct do
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
end
