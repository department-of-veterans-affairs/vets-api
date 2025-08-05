# frozen_string_literal: true

FactoryBot.define do
  factory :debts_api_digital_dispute_submission, class: 'DebtsApi::V0::DigitalDisputeSubmission' do
    user_uuid { SecureRandom.uuid }
    association :user_account, factory: :user_account
    state { :pending }
  end
end
