# frozen_string_literal: true

FactoryBot.define do
  factory :form1010cg_submission, class: 'Form1010cg::Submission' do
    claim_guid { SecureRandom.uuid }
    carma_case_id { "#{Faker::Alphanumeric.alphanumeric(number: 15)}CAK" }
    accepted_at { DateTime.now }

    trait :with_claim do
      association :claim, factory: :caregivers_assistance_claim
    end
  end
end
