# frozen_string_literal: true

FactoryBot.define do
  factory :central_mail_submission do
    association :central_mail_claim, factory: :education_career_counseling_claim
    state { 'success' }
  end
end
