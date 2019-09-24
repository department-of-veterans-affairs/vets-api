# frozen_string_literal: true

FactoryBot.define do
  factory :va526ez, class: SavedClaim::DisabilityCompensation::Form526IncreaseOnly do
    form {
      JSON.parse(
        File.read('spec/support/disability_compensation_form/front_end_submission.json')
      )['form526'].to_json
    }
  end
end
