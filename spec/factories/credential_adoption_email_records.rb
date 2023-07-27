# frozen_string_literal: true

FactoryBot.define do
  factory :credential_adoption_email_record do
    icn { '123456ABCDEF' }
    email_address { 'example@example.com' }
    email_template_id { '08d9f04-ae3f-4b73-b932-3ad175d21ba9' }
    email_triggered_at { DateTime.now }
  end
end
