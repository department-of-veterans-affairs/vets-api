# frozen_string_literal: true

FactoryBot.define do
  factory :preference do
    sequence(:code) { |n| "preference_#{n}" }
    sequence(:title) { |n| "Title of Preference #{n}" }

    trait :with_choices do
      after :create do |preference|
        create_list :preference_choice, 3, preference: preference
      end
    end

    trait :notifications do
      code { 'notifications' }
      title { 'Notifications' }
      after :create do |preference|
        create :preference_choice, preference: preference, code: 'push-mobile',  description: 'Push alert to mobile?'
        create :preference_choice, preference: preference, code: 'text-mobile',  description: 'Text alert to mobile?'
        create :preference_choice, preference: preference, code: 'push-browser', description: 'Push alert to browser?'
        create :preference_choice, preference: preference, code: 'email',        description: 'Email notifications?'
      end
    end

    trait :benefits do
      code { 'test-benefits' }
      title { 'Test Benefits' }
      benefits = %w[test-health-care
                    test-disability
                    test-appeals
                    test-education-training
                    test-careers-employment
                    test-pension
                    test-housing-assistance
                    test-life-insurance
                    test-burials-memorials
                    test-family-caregiver-benefits]

      after :create do |preference|
        benefits.each do |benefit|
          create :preference_choice, preference: preference,
                                     code: benefit,
                                     description: benefit.tr('-', ' ')
        end
      end
    end
  end
end
