# frozen_string_literal: true

FactoryBot.define do
  factory :travel_pay_meal_expense, class: 'TravelPay::MealExpense' do
    description { 'Lunch during travel' }
    vendor_name { 'Subway' }
    cost_requested { 15.00 }
    purchase_date { Time.current }
    claim_id { nil }
    receipt { nil }

    trait :with_claim_id do
      claim_id { SecureRandom.uuid }
    end

    trait :with_receipt do
      receipt { double('Receipt', id: SecureRandom.uuid) }
    end

    trait :high_cost do
      cost_requested { 500.00 }
    end

    trait :minimal_cost do
      cost_requested { 1.00 }
    end

    trait :with_long_description do
      description { 'A' * 200 }
    end

    trait :with_blank_vendor_name do
      vendor_name { '' } # whitespace only, should fail validation
    end

    trait :with_whitespace_vendor_name do
      vendor_name { '   ' } # whitespace only, should fail validation
    end

    initialize_with { TravelPay::MealExpense.new(attributes) }
  end
end
