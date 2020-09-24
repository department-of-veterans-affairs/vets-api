# frozen_string_literal: true

FactoryBot.define do
  factory :ppiu_payment_account, class: 'EVSS::PPIU::PaymentAccount' do
    sequence(:account_number, 10) { |n| "123456#{n}" }

    account_type { 'Checking' }
    financial_institution_name { 'Bank of Ad Hoc' }
    financial_institution_routing_number { '123456789' }
  end
end
