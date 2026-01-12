# frozen_string_literal: true

FactoryBot.define do
  factory :va0839, class: 'SavedClaim::EducationBenefits::VA0839', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0839', 'minimal.json').read }
  end

  factory :va0839_overflow, class: 'SavedClaim::EducationBenefits::VA0839', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0839', 'overflow.json').read }
  end

  factory :va0839_withdrawal, class: 'SavedClaim::EducationBenefits::VA0839', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0839', 'withdrawal.json').read }
  end

  factory :va0839_unlimited, class: 'SavedClaim::EducationBenefits::VA0839', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0839', 'unlimited.json').read }
  end
end
