# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    sequence :id do |n|
      n
    end

    category { 'OTHER' }
    sequence :subject do |n|
      "Subject #{n}"
    end

    sequence :body do |n|
      "Body #{n}"
    end

    attachment { false }
    sent_date { 'Thu, 11 Jul 2013 20:25:54 GMT' }
    sender_id { 1 }
    sender_name { 'Sender 1' }
    recipient_id { 613_586 }
    recipient_name { 'Recipient 1' }
    read_receipt { 'READ' }

    trait :with_attachments do
      attachment { true }
      attachments { build_list(:attachment, 3) }
    end

    factory :message_thread_details, class: 'MessageThreadDetails' do
      message_id { 123 }
      thread_id { 456 }
      folder_id { 789 }
      draft_date { Time.current.iso8601 }
      to_date { Time.current.iso8601 }
      has_attachments { false }
    end
  end
end
