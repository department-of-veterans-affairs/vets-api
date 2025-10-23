# frozen_string_literal: true

FactoryBot.define do
  factory :travel_pay_base_expense, class: 'TravelPay::BaseExpense' do
    description { 'General expense' }
    cost_requested { 100.00 }
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

    # Initialize method override to properly instantiate the PORO
    initialize_with { TravelPay::BaseExpense.new(attributes) }
  end
end
