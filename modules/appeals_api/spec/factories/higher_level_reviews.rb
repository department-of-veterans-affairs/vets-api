# frozen_string_literal: true

FactoryBot.define do
  factory :higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996.json"
    end
    trait :status_received do
      status { 'received' }
    end
  end

  factory :extra_higher_level_review, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
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
end
