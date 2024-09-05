# frozen_string_literal: true

FactoryBot.define do
  factory :lighthouse526_document_upload do
    association :form526_submission
    association :form_attachment
    lighthouse_document_request_id { Faker::Internet.uuid }
    aasm_state { 'pending' } # initial status
    document_type { 'BDD Instructions' }
    error_message { 'Something Broke' }
    lighthouse_processing_started_at { nil }
    lighthouse_processing_ended_at { nil }
    status_last_polled_at { nil }
    last_status_response { nil }
  end
end
