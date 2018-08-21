# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    uuid { SecureRandom.uuid }
    idme_uuid { SecureRandom.uuid }
  end
end
