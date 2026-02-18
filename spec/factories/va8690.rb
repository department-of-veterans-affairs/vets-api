# frozen_string_literal: true

FactoryBot.define do
  factory :va0989, class: 'SavedClaim::EducationBenefits::VA8690', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '8690', 'minimal.json').read }
  end
end
