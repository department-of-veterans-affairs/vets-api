# frozen_string_literal: true

FactoryBot.define do
  factory :lighthouse_document_upload do
    association :form526_submission
    association :form_attachment
    lighthouse_document_request_id { Faker::Internet.uuid }
    aasm_state { 'pending_vbms_completion' }
    document_type { 'BDD Instructions' }
  end
end
