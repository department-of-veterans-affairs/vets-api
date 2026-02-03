# frozen_string_literal: true

class MessageThreadDetails < Message
  attribute :message_id, Integer
  attribute :thread_id, Integer
  attribute :folder_id, Integer
  attribute :message_body, String
  attribute :draft_date, Vets::Type::DateTimeString
  attribute :to_date, Vets::Type::DateTimeString
  attribute :has_attachments, Bool, default: false
  attribute :reply_disabled, Bool, default: false
  attribute :attachments, Array
end
