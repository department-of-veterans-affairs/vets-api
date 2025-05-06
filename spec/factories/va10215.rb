# frozen_string_literal: true

FactoryBot.define do
  factory :va10215, class: 'SavedClaim::EducationBenefits::VA10215', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10215', 'minimal.json').read }
  end
end
