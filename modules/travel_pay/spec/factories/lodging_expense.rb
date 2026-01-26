# frozen_string_literal: true

FactoryBot.define do
  factory :travel_pay_lodging_expense, class: 'TravelPay::LodgingExpense' do
    description { 'Hotel stay' }
    cost_requested { 120.00 }
    purchase_date { Time.current }
    claim_id { nil }
    receipt { nil }
    vendor { 'Holiday Inn' }
    check_in_date { Date.current }
    check_out_date { Date.current + 2.days }

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

    trait :with_blank_vendor do
      vendor { '' } # empty string, should fail validation
    end

    trait :with_whitespace_vendor do
      vendor { '   ' } # whitespace only, should fail validation
    end

    initialize_with { TravelPay::LodgingExpense.new(attributes) }
  end
end
