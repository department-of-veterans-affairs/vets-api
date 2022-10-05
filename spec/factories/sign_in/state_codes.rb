# frozen_string_literal: true

FactoryBot.define do
  factory :state_code, class: 'SignIn::StateCode' do
    code { SecureRandom.hex }
  end
end
