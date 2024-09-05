# frozen_string_literal: true

FactoryBot.define do
  factory :message_thread do
    thread_id { 456 }
    folder_id { 789 }
    message_id { 123 }
    thread_page_size { 454 }
    message_count { 1 }
    category { 'OTHER' }
    subject { 'Subject' }
    triage_group_name { 'WORKLOAD CAPTURE_SLC 4_Mohammad' }
    sent_date { Time.current }
    draft_date { Time.current }
    sender_id { 1 }
    sender_name { 'Sender 1' }
    recipient_name { 'Recipient 1' }
    recipient_id { 613_586 }
    proxySender_name { 'Proxy Sender 1' }
    has_attachment { false }
    unsent_drafts { false }
    unread_messages { false }
  end
end
