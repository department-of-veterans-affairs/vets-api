# frozen_string_literal: true

FactoryBot.define do
  factory :va0989, class: 'SavedClaim::EducationBenefits::VA0989', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0989', 'minimal.json').read }
  end
end
