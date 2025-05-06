# frozen_string_literal: true

FactoryBot.define do
  factory :va1990s, class: 'SavedClaim::EducationBenefits::VA1990s', parent: :education_benefits do
    factory :va1990s_full_form do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1990s', 'kitchen_sink.json').read }
    end

    factory :va1990s_minimum_form do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1990s', 'simple.json').read }
    end
  end
end
