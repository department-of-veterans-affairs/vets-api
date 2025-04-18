# frozen_string_literal: true

FactoryBot.define do
  factory :appeal_submission_module, class: 'AppealSubmission' do
    transient do
      user_verification { create(:idme_user_verification) }
      user { create(:user, :loa3, ssn: '212222112', idme_uuid: user_verification.idme_uuid) }
    end
    user_uuid { user.uuid }
    user_account { user_verification.user_account }
    submitted_appeal_uuid { SecureRandom.uuid }
    type_of_appeal { 'NOD' }
    board_review_option { 'evidence_submission' }
    upload_metadata { DecisionReviews::V1::Service.file_upload_metadata(user) }
  end

  trait :with_one_upload_module do
    after(:create) do |submission|
      create(:appeal_submission_upload_module, appeal_submission: submission)
    end
  end
end
