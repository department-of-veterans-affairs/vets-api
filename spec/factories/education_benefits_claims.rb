# frozen_string_literal: true
FactoryGirl.define do
  factory :education_benefits_claim do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1990)
    end
  end
end
