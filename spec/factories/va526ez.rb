# frozen_string_literal: true

FactoryBot.define do
  factory :va526ez, class: 'SavedClaim::DisabilityCompensation::Form526AllClaim' do
    form {
      JSON.parse(
        File.read('spec/support/disability_compensation_form/all_claims_fe_submission.json')
      )['form526'].to_json
    }
  end
end
