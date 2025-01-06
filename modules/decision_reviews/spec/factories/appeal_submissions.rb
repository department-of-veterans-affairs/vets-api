# frozen_string_literal: true

FactoryBot.define do
  factory :appeal_submission_module, class: 'AppealSubmission' do
    user_uuid do
      user = create(:user, :loa3, ssn: '212222112')
      user.uuid
    end
    submitted_appeal_uuid { SecureRandom.uuid }
    type_of_appeal { 'NOD' }
    board_review_option { 'evidence_submission' }
    upload_metadata do
      user = User.find(user_uuid)
      DecisionReviews::V1::Service.file_upload_metadata(user)
    end
  end

  trait :with_one_upload_module do
    after(:create) do |submission|
      create(:appeal_submission_upload_module, appeal_submission: submission)
    end
  end
end
