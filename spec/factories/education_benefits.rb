# frozen_string_literal: true
FactoryGirl.define do
  factory :education_benefits, class: SavedClaim::EducationBenefits do
  end

  factory :saved_claim, class: SavedClaim do
  end

  factory :education_benefits_submission, class: EducationBenefitsSubmission do
  end
end
