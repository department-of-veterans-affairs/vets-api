# frozen_string_literal: true

FactoryBot.define do
  factory :va0976, class: 'SavedClaim::EducationBenefits::VA0976', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0976', 'minimal.json').read }
  end

  factory :va0976_overflow, class: 'SavedClaim::EducationBenefits::VA0976', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0976', 'overflow.json').read }
  end
end
