# frozen_string_literal: true

FactoryBot.define do
  factory :form_attachment do
    guid { Faker::Internet.uuid }
    file_data { Faker::Json.to_s }
    type { 'SupportingEvidenceAttachment' }
  end
end
