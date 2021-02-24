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
end
