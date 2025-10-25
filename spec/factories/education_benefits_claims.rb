# frozen_string_literal: true

FactoryBot.define do
  factory :education_benefits_claim do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va1990)
    end
  end

  factory :education_benefits_claim_10203, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= build(:va10203)
    end

    trait :with_stem do
      education_stem_automated_decision { build(:education_stem_automated_decision) }
    end

    trait :with_denied_stem do
      education_stem_automated_decision { build(:education_stem_automated_decision, :denied) }
    end
  end
end
