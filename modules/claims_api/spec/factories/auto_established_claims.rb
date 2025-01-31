# frozen_string_literal: true

require 'claims_api/special_issue_mappers/bgs'

FactoryBot.define do
  # factories
  factory :auto_established_claim, class: 'ClaimsApi::AutoEstablishedClaim',
                                   parent: :claims_api_base_factory do
    id { SecureRandom.uuid }
    source { 'oddball' }
    form_data do
      json = JSON.parse(File
             .read(Rails.root.join(*'/modules/claims_api/spec/fixtures/form_526_json_api.json'.split('/')).to_s))
      attributes = json['data']['attributes']
      attributes['disabilities'][0]['specialIssues'] = []
      attributes
    end
  end
  factory :auto_established_claim_with_supporting_documents, parent: :auto_established_claim do
    after(:create) do |auto_established_claim|
      create_list(:supporting_document, 1, auto_established_claim:)
    end
  end

  factory :auto_established_claim_v2, class: 'ClaimsApi::AutoEstablishedClaim', parent: :auto_established_claim do
    id { SecureRandom.uuid }
    status { 'pending' }
    form_data do
      json = JSON.parse(File
             .read(
               Rails.root.join(
                 *'/modules/claims_api/spec/fixtures/v2/veterans/disability_compensation/form_526_json_api.json'
                 .split('/')
               ).to_s
             ))
      json['data']['attributes']
    end
  end
  factory :auto_established_claim_va_gov, class: 'ClaimsApi::AutoEstablishedClaim', parent: :auto_established_claim do
    id { SecureRandom.uuid }
    cid { '0oagdm49ygCSJTp8X297' }
    transaction_id { Faker::Number.number(digits: 20) }
    created_at { Faker::Date.between(from: 1.day.ago, to: Time.zone.now) }
  end

  # traits
  trait :flashes do
    flashes { %w[Hardship Homeless] }
  end
  trait :special_issues do
    form_data do
      json = JSON.parse(File
             .read(Rails.root.join(*'/modules/claims_api/spec/fixtures/form_526_json_api.json'.split('/')).to_s))
      json['data']['attributes']
    end
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
  trait :special_issues_v2 do
    form_data do
      json = JSON.parse(File
             .read(
               Rails.root.join(
                 *'/modules/claims_api/spec/fixtures/v2/veterans/disability_compensation/form_526_json_api.json'
                 .split('/')
               ).to_s
             ))
      json['data']['attributes']
    end
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
  trait :autoCestPDFGeneration_disabled do
    form_data do
      json = JSON.parse(File
              .read(Rails.root.join(*'/modules/claims_api/spec/fixtures/form_526_json_api.json'.split('/'))
              .to_s))
      json['data']['attributes']['autoCestPDFGenerationDisabled'] = false
      json['data']['attributes']
    end
  end

  trait :set_transaction_id do
    transaction_id { '25' }
  end
end
