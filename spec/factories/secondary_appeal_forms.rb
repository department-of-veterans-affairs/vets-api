# frozen_string_literal: true

FactoryBot.define do
  factory :secondary_appeal_form do
    guid { SecureRandom.uuid }
    form do
      {
        privacyAgreementAccepted: true
      }.to_json
    end
    appeal_submission_id { SecureRandom.uuid }
  end
end
