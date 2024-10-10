# frozen_string_literal: true

FactoryBot.define do
  factory :form4142_status_polling_record do
    benefits_intake_uuid { 'MyString' }
    submission_id { 1 }
    submission_class { 'Form526Submission' }
    status { 0 }

    trait :pending do
      status { 0 }
    end

    trait :has_vcr_data do
      benefits_intake_uuid { '6d8433c1-cd55-4c24-affd-f592287a7572' }
    end

    trait :errored do
      status { 1 }
    end

    trait :success do
      status { 2 }
    end
  end
end
