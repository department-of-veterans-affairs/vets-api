# frozen_string_literal: true

FactoryBot.define do
  factory :va10216, class: 'SavedClaim::EducationBenefits::VA10216', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10216', 'minimal.json').read }
  end
end
