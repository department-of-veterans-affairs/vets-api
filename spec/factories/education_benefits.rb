# frozen_string_literal: true
FactoryGirl.define do
  factory :education_benefits, class: SavedClaim::EducationBenefits do
    after(:build) do |saved_claim|
      saved_claim.education_benefits_claim ||= build(:education_benefits_claim)
    end
  end
end
