# frozen_string_literal: true

FactoryBot.define do
  factory :va0839, class: 'SavedClaim::EducationBenefits::VA0839', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0839', 'minimal.json').read }
  end
end
