# frozen_string_literal: true

FactoryBot.define do
  factory :bank_name do
    routing_number { '026009593' }
    bank_name { 'Bank of America' }
  end
end
