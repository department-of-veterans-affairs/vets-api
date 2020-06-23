# frozen_string_literal: true

FactoryBot.define do
  factory :form1010cg_submission, class: 'Form1010cg::Submission' do
    saved_claim_id { create(:caregivers_assistance_claim).id }
    carma_case_id { Faker::Alphanumeric.alphanumeric(number: 15) + 'CAK' }
    submitted_at { DateTime.now }
  end
end
