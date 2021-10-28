# frozen_string_literal: true

FactoryBot.define do
  factory :receive_application, class: 'Preneeds::ReceiveApplication' do
    tracking_number { 'abcd1234' }
    return_code { 200 }
    application_uuid { 'f09c3ff2-c047-49f7-b2f5-bc6a2e5b88a9' }
    return_description { 'PreNeed Application received.' }
  end
end
