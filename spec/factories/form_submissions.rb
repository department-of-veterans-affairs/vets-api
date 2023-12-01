# frozen_string_literal: true

FactoryBot.define do
  factory :form_submission do
    benefits_intake_uuid { SecureRandom.uuid }
  end
end
