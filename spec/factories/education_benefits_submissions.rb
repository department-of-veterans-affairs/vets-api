# frozen_string_literal: true

FactoryBot.define do
  factory :education_benefits_submission do
    region { 'eastern' }
    chapter33 { true }

    after(:build) do |education_benefits_submission|
      # have to do it this way otherwise 2 submissions get created because of education benefits claim callback
      education_benefits_submission.education_benefits_claim = FactoryBot.build(:education_benefits_claim)
      education_benefits_submission.education_benefits_claim.saved_claim = FactoryBot.build(:va1990)
    end
  end
end
