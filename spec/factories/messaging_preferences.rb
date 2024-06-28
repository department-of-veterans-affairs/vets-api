# frozen_string_literal: true

FactoryBot.define do
  factory :messaging_preference do
    email_address { 'example@email.com' }
    frequency { 'each_message' }
  end
end
