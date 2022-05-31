# frozen_string_literal: true

FactoryBot.define do
  factory :higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_200996.json"
    end
    trait :status_error do
      status { 'error' }
    end
    trait :status_received do
      status { 'received' }
    end
  end

  factory :extra_higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_200996_extra.json"
    end
    trait :status_received do
      status { 'received' }
    end
  end

  factory :minimal_higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_200996_minimum.json"
    end
    trait :status_received do
      status { 'received' }
    end
  end

  factory :higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200996.json"
    end
  end

  factory :extra_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200996_headers_extra.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200996_extra.json"
    end
  end

  factory :minimal_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      # why are we using v1 headers?
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_200996_headers_minimum.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_200996_minimum.json"
    end
  end
end
