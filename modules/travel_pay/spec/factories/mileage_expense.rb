# frozen_string_literal: true

FactoryBot.define do
  factory :travel_pay_mileage_expense, class: 'TravelPay::MileageExpense' do
    description { 'Travel to medical appointment' }
    cost_requested { 25.50 }
    purchase_date { Time.current }
    claim_id { nil }
    receipt { nil }
    trip_type { TravelPay::Constants::TRIP_TYPES[:one_way] }
    requested_mileage { nil }

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

    trait :round_trip do
      trip_type { TravelPay::Constants::TRIP_TYPES[:round_trip] }
    end

    trait :one_way do
      trip_type { TravelPay::Constants::TRIP_TYPES[:one_way] }
    end

    trait :with_requested_mileage do
      requested_mileage { 42.5 }
    end

    trait :short_trip do
      requested_mileage { 5.2 }
      cost_requested { 3.50 }
    end

    trait :long_trip do
      requested_mileage { 125.8 }
      cost_requested { 75.00 }
    end

    # Initialize method override to properly instantiate the PORO
    initialize_with { TravelPay::MileageExpense.new(attributes) }
  end
end
