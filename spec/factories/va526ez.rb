# frozen_string_literal: true

FactoryBot.define do
  factory :va526ez, class: 'SavedClaim::DisabilityCompensation::Form526AllClaim' do
    form {
      JSON.parse(
        File.read('spec/support/disability_compensation_form/all_claims_fe_submission.json')
      )['form526'].to_json
    }
  end

  factory :va526ez_v2, class: 'SavedClaim::DisabilityCompensation::Form526AllClaim' do
    # for Form 21-0781V2
    form {
      JSON.parse(
        File.read('spec/support/disability_compensation_form/all_claims_with_0781v2_fe_submission.json')
      )['form526'].to_json
    }
  end
end
