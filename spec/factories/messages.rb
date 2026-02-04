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

    reply_disabled { true }
    attachment { false }
    sent_date { 'Thu, 11 Jul 2013 20:25:54 GMT' }
    sender_id { 1 }
    sender_name { 'Sender 1' }
    recipient_id { 613_586 }
    recipient_name { 'Recipient 1' }
    read_receipt { 'READ' }

    trait :with_attachments do
      attachment { true }
      attachments { build_list(:attachment, 4) }

      after(:build) do |message, _evaluator|
        message.attachments.each_with_index do |attachment, index|
          idx = index + 1
          message.send("attachment#{idx}_id=", attachment.id)
          message.send("attachment#{idx}_name=", attachment.name)
          message.send("attachment#{idx}_size=", attachment.attachment_size)
        end
      end
    end

    trait :with_attachments_for_thread do
      attachment { true }
      attachments do
        Array.new(2) do |i|
          {
            attachment_id: 5_565_677 + i,
            attachment_name: "patientAttach#{i.zero? ? '' : i + 1}.jpg",
            attachment_size: 18_609 + (i * 1391),
            attachment_mime_type: 'image/jpeg'
          }
        end
      end
    end

    factory :message_thread_details, class: 'MessageThreadDetails' do
      reply_disabled { false }
      message_id { 123 }
      thread_id { 456 }
      folder_id { 789 }
      draft_date { Time.current.iso8601 }
      to_date { Time.current.iso8601 }
      has_attachments { false }
    end
  end
end
