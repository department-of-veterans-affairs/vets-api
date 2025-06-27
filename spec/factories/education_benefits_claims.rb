# frozen_string_literal: true

FactoryBot.define do
  factory :education_benefits_claim do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= FactoryBot.build(:va1990)
    end
  end

  factory :education_benefits_claim_1990e, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= FactoryBot.build(:va1990e)
    end
  end

  factory :education_benefits_claim_1990n, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= FactoryBot.build(:va1990n)
    end
  end

  factory :education_benefits_claim_10203, class: 'EducationBenefitsClaim' do
    after(:build) do |education_benefits_claim|
      education_benefits_claim.saved_claim ||= FactoryBot.build(:va10203)
    end

    trait :with_stem do
      education_stem_automated_decision { FactoryBot.build(:education_stem_automated_decision) }
    end

    trait :with_denied_stem do
      education_stem_automated_decision { FactoryBot.build(:education_stem_automated_decision, :denied) }
    end
  end
end
