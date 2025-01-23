# frozen_string_literal: true

FactoryBot.define do
  factory :lighthouse_document do
    claim_id { Faker::Internet.uuid }
    participant_id { Faker::Internet.uuid }
    document_type { 'L023' }
    file_name { Faker::File.file_name }
  end
end
