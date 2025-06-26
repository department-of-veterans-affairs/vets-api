# frozen_string_literal: true

FactoryBot.define do
  factory :va_1919, class: 'SavedClaim::EducationBenefits::VA1919', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1919', 'minimal.json').read }
  end
end 