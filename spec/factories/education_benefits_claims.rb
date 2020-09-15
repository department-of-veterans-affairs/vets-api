# frozen_string_literal: true

FactoryBot.define do
  factory :education_benefits_claim do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1990)
    end
  end

  factory :education_benefits_claim_1990e, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1990e)
    end
  end

  factory :education_benefits_claim_1990n, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1990n)
    end
  end

  factory :education_benefits_claim_10203, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va10203)
    end
  end
end
