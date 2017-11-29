# frozen_string_literal: true
FactoryBot.define do
  factory :education_benefits_claim do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1990)
    end
  end

  %w(1990e 1990n).each do |form_type|
    factory :"education_benefits_claim_#{form_type}", class: 'EducationBenefitsClaim' do
      after(:build) do |education_benefits_claim|
        education_benefits_claim.saved_claim ||= build(:"va#{form_type}")
      end
    end
  end
end
