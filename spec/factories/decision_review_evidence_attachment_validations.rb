# frozen_string_literal: true

FactoryBot.define do
  factory :decision_review_evidence_attachment_validation do
    decision_review_evidence_attachment_guid { SecureRandom.uuid }
  end
end
