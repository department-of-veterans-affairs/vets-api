# frozen_string_literal: true

FactoryBot.define do
  factory :appeal_submission_upload_module, class: 'AppealSubmissionUpload' do
    decision_review_evidence_attachment_guid { SecureRandom.uuid }
    appeal_submission_id { SecureRandom.uuid }
  end
end
