# frozen_string_literal: true

FactoryBot.define do
  factory :supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    evidence_submission_indicated { true }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200995_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200995.json"
    end

    trait :status_success do
      status { 'success' }
    end

    trait :status_error do
      status { 'error' }
    end

    trait :status_submitted do
      status { 'submitted' }
    end
  end

  factory :extra_supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    evidence_submission_indicated { true }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200995_headers_extra.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200995_extra.json"
    end
  end

  factory :minimal_supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200995_headers_minimum.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200995.json"
    end
  end
end
