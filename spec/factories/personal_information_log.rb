# frozen_string_literal: true

FactoryBot.define do
  factory :personal_information_log do
    data { { foo: 1 } }
    error_class { 'StandardError' }
  end
end
