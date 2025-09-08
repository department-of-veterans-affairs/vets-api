# frozen_string_literal: true

FactoryBot.define do
  factory :debt_transaction_log do
    transaction_type { 'waiver' }
    state { 'pending' }
    debt_identifiers { ['debt123'] }
    user_uuid { SecureRandom.uuid }
    transaction_started_at { Time.current }
    association :transactionable, factory: :debts_api_form5655_submission

    trait :dispute do
      transaction_type { 'dispute' }
      association :transactionable, factory: :debts_api_digital_dispute_submission
    end

    trait :submitted do
      state { 'submitted' }
    end

    trait :completed do
      state { 'completed' }
      transaction_completed_at { Time.current }
    end

    trait :failed do
      state { 'failed' }
      transaction_completed_at { Time.current }
    end
  end
end
