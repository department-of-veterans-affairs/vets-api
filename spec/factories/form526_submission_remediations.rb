# frozen_string_literal: true

FactoryBot.define do
  factory :form526_submission_remediation do
    association :form526_submission
    lifecycle { ['datetime -- context'] }
    success { true }
    ignored_as_duplicate { false }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end
end
