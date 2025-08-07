# frozen_string_literal: true

FactoryBot.define do
  factory :travel_pay_base_expense, class: 'TravelPay::BaseExpense' do
    description { 'Travel expense' }
    cost_requested { 100.00 }
    purchase_date { Time.current }
    claim_id { nil }
    receipt { nil }

    trait :with_claim_id do
      claim_id { SecureRandom.uuid }
    end

    trait :with_receipt do
      receipt { 'mock_receipt_object' }
    end

    trait :hotel_expense do
      description { 'Hotel accommodation' }
      cost_requested { 150.00 }
    end

    trait :meal_expense do
      description { 'Meal expense' }
      cost_requested { 45.75 }
    end

    trait :transportation_expense do
      description { 'Taxi fare' }
      cost_requested { 25.50 }
    end

    trait :high_cost do
      cost_requested { 500.00 }
    end

    trait :minimal_cost do
      cost_requested { 1.00 }
    end

    # Initialize method override to properly instantiate the PORO
    initialize_with { TravelPay::BaseExpense.new(attributes) }
  end
end
