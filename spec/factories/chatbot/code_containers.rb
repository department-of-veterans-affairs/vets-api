# frozen_string_literal: true

FactoryBot.define do
  factory :chatbot_code_container, class: 'Chatbot::CodeContainer' do
    code { SecureRandom.hex }
    icn { Faker::Alphanumeric.alphanumeric(number: 10) }
  end
end
