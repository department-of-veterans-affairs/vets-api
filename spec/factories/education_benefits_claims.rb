# frozen_string_literal: true

FactoryBot.define do
  factory :education_benefits_claim do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1990)
    end
  end

  %w[1990e 1990n 1995s].each do |form_type|
    factory :"education_benefits_claim_#{form_type}", class: 'EducationBenefitsClaim' do
      after(:build) do |education_benefits_claim|
        education_benefits_claim.saved_claim ||= build(:"va#{form_type}")
      end
    end
  end

  factory :education_benefits_claim_1995stem, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1995_with_stem)
    end
  end
end
