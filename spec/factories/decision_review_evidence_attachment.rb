# frozen_string_literal: true

FactoryBot.define do
  factory :decision_review_evidence_attachment do
    guid { SecureRandom.uuid }
  end
end
