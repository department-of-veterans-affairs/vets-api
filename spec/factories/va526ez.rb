# frozen_string_literal: true

FactoryBot.define do
  factory :va526ez, class: 'SavedClaim::DisabilityCompensation::Form526AllClaim' do
    form {
      JSON.parse(
        File.read('spec/support/disability_compensation_form/submit_all_claim/all.json')
      )['form526'].to_json
    }
  end

  factory :va526ez_0781v2, class: 'SavedClaim::DisabilityCompensation::Form526AllClaim' do
    # for Form 21-0781V2
    form {
      JSON.parse(
        File.read('spec/support/disability_compensation_form/submit_all_claim/0781v2.json')
      )['form526'].to_json
    }
  end
end
