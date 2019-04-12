# frozen_string_literal: true

FactoryBot.define do
  factory :ppiu_payment_account, class: 'EVSS::PPIU::PaymentAccount' do
    account_type 'Checking'
    financial_institution_name 'Bank of Ad Hoc'
    account_number '12345678'
    financial_institution_routing_number '123456789'
  end
end
