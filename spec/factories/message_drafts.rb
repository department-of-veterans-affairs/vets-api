# frozen_string_literal: true
FactoryBot.define do
  factory :message_draft do
    id 573_073
    category 'OTHER'
    subject 'Subject 1'
    body 'Body 1'
    attachment false
    sent_date ''
    sender_id 384_939
    sender_name 'MVIONE, TEST'
    recipient_id 585_986
    recipient_name 'Triage group 311070 test 2'
    read_receipt 'null'
    has_message false

    trait :with_message do
      has_message true
    end
  end
end
