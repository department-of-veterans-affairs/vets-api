# frozen_string_literal: true
FactoryGirl.define do
  factory :education_benefits, class: SavedClaim::EducationBenefits do
  end

  factory :education_benefits_1990, class: SavedClaim::EducationBenefits::VA1990 do
  end
end
