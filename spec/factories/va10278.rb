# frozen_string_literal: true

FactoryBot.define do
  factory :va10278, class: 'SavedClaim::EducationBenefits::VA10278', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10278', 'minimal.json').read }
  end
end
