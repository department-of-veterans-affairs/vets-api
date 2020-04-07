# frozen_string_literal: true

FactoryBot.define do
  factory :higher_level_review_submission, class: 'AppealsApi::HigherLevelReviewSubmission' do
    id { SecureRandom.uuid }
    auth_headers { {} }
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996.json"
    end
  end
end
