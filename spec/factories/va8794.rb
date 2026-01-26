# frozen_string_literal: true

FactoryBot.define do
  factory :va8794, class: 'SavedClaim::EducationBenefits::VA8794', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '8794', 'minimal.json').read }
  end

  factory :va8794_overflow, class: 'SavedClaim::EducationBenefits::VA8794', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '8794', 'overflow.json').read }
  end
end
