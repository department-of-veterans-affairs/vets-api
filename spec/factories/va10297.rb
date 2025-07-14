# frozen_string_literal: true

FactoryBot.define do
  factory :va10297, class: 'SavedClaim::EducationBenefits::VA10297', parent: :education_benefits do
    factory :va10297_simple_form do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10297', 'simple.json').read }
    end
  end
end
