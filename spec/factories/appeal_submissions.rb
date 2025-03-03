# frozen_string_literal: true

FactoryBot.define do
  factory :appeal_submission do
    user_uuid do
      user = create(:user, :loa3, ssn: '212222112')
      user.uuid
    end
    submitted_appeal_uuid { SecureRandom.uuid }
    type_of_appeal { 'NOD' }
    board_review_option { 'evidence_submission' }
    upload_metadata do
      user = User.find(user_uuid)
      {
        'veteranFirstName' => user.first_name,
        'veteranLastName' => user.last_name,
        'zipCode' => user.postal_code.to_s,
        'fileNumber' => user.ssn.to_s.strip,
        'source' => 'va.gov',
        'businessLine' => 'BVA'
      }.to_json
    end
  end

  trait :with_one_upload do
    after(:create) do |submission|
      create(:appeal_submission_upload, appeal_submission: submission)
    end
  end
end
