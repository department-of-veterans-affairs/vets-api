# frozen_string_literal: true

FactoryBot.define do
  factory :supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200995_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200995.json"
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

    trait :completed_a_day_ago do
      updated_at { 1.day.ago }
      status { 'success' }
    end

    trait :completed_a_week_ago do
      updated_at { 8.days.ago }
      status { 'success' }
    end
  end

  factory :extra_supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200995_headers_extra.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200995_extra.json"
    end
  end
end
