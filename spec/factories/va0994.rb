# frozen_string_literal: true

FactoryBot.define do
  factory :va0994, class: 'SavedClaim::EducationBenefits::VA0994', parent: :education_benefits do
    factory :va0994_full_form do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0994', 'kitchen_sink.json').read }
    end

    factory :va0994_no_education_benefits do
      form {
        Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0994',
                        'kitchen_sink_no_education_benefits.json').read
      }
    end

    factory :va0994_minimum_form do
      form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0994', 'simple.json').read }
    end
  end
end
