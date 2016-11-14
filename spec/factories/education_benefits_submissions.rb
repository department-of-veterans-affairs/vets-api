# frozen_string_literal: true
FactoryGirl.define do
  factory :education_benefits_submission do
    region('eastern')
    chapter33(true)

    after(:build) do |education_benefits_submission|
      # have to it this way otherwise 2 submissions get created because of education benefits claim callback
      education_benefits_submission.education_benefits_claim = build(:education_benefits_claim)
    end
  end
end
