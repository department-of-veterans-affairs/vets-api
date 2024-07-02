# frozen_string_literal: true

FactoryBot.define do
  factory :prescription_preference do
    email_address { 'example@email.com' }
    rx_flag { false }
  end
end
