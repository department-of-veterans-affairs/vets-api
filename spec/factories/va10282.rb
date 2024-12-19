# frozen_string_literal: true

FactoryBot.define do
  factory :va10282, class: 'SavedClaim::EducationBenefits::VA10282', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10282', 'minimal.json').read }
  end
end
