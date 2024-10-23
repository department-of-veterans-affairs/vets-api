# frozen_string_literal: true

FactoryBot.define do
  factory :evidence_waiver_submission,
          class: 'ClaimsApi::EvidenceWaiverSubmission',
          parent: :claims_api_base_factory do
    vbms_error_message { 'vbms error' }
    bgs_error_message { 'bgs error' }
    vbms_upload_failure_count { 0 }
    bgs_upload_failure_count { 0 }
  end
end
