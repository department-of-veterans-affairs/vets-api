# frozen_string_literal: true

FactoryBot.define do
  factory :higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996.json"
    end
    trait :status_error do
      status { 'error' }
    end
    trait :status_received do
      status { 'received' }
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

  factory :extra_higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_extra.json"
    end
    trait :status_received do
      status { 'received' }
    end
  end

  factory :minimal_higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_minimum.json"
    end
    trait :status_received do
      status { 'received' }
    end
  end

  factory :higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_headers_v2.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_v2.json"
    end
  end

  factory :extra_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_headers_extra_v2.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_extra_v2.json"
    end
  end

  factory :minimal_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_headers_minimum.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_minimum_v2.json"
    end
  end
end
