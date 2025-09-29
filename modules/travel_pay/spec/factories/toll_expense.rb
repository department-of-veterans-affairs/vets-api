# frozen_string_literal: true

FactoryBot.define do
  factory :travel_pay_toll_expense, class: 'TravelPay::TollExpense' do
    description { 'Bridge toll' }
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

    initialize_with { TravelPay::TollExpense.new(attributes) }
  end
end
