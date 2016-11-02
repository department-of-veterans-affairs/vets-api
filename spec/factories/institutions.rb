# frozen_string_literal: true
FactoryGirl.define do
  factory :institution do
    association :institution_type

    sequence(:facility_code) { |n| "facility code #{n}" }
    sequence(:institution) { |n| "institution #{n}" }
    sequence(:country) { |n| "country #{n}" }

    trait :in_nyc do
      city 'new york'
      state 'ny'
      country 'usa'
    end

    trait :in_new_rochelle do
      city 'new rochelle'
      state 'ny'
      country 'usa'
    end

    trait :in_chicago do
      city 'chicago'
      state 'il'
      country 'usa'
    end

    trait :uchicago do
      institution 'university of chicago - not in chicago'
      city 'some other city'
      state 'il'
      country 'usa'
    end

    trait :start_like_harv do
      sequence(:institution) { |n| ["harv#{n}", "harv #{n}"].sample }
      city 'boston'
      state 'ma'
      country 'usa'
    end

    trait :contains_harv do
      sequence(:institution) { |n| ["hasharv#{n}", "has harv #{n}"].sample }
      city 'boston'
      state 'ma'
      country 'usa'
    end
  end
end
