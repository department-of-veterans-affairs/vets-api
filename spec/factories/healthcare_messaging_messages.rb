# frozen_string_literal: true
FactoryGirl.define do
  factory :message do
    sequence :id do |n|
      n
    end

    sequence :subject do |n|
      "Subject #{n}"
    end

    sequence :body do |n|
      "Body #{n}"
    end

    category 'OTHER'
    recipient_id 585_986

    factory :message_for_model do
      attachment false
      sent_date 'Thu, 11 Jul 2013 20:25:54 GMT'
      sender_id 1
      sender_name 'Sender 1'
      recipient_name 'Recipient 1'
      read_receipt 'READ'
    end
  end
end
