# frozen_string_literal: true
FactoryGirl.define do
  factory :message, class: VAHealthcareMessaging::Message do
    sequence :id do |n|
      n
    end

    category 'CATEGORY'
    subject 'SUBJECT'
    body 'BODY'
    attachment false
    sent_date 'Thu, 11 Jul 2013 20:25:54 GMT'
    sender_id 1
    sender_name 'Sender 1'
    recipient_id 1
    recipient_name 'Recipient 1'
    read_receipt 'READ'
  end
end
