# frozen_string_literal: true

class MessageThreadDetails < Message
  attribute :message_id, Integer
  attribute :thread_id, Integer
  attribute :folder_id, Integer
  attribute :message_body, String
  attribute :draft_date, Vets::Type::DateTimeString
  attribute :to_date, Vets::Type::DateTimeString
  attribute :has_attachments, Bool, default: false
  (1..4).each do |i|
    attribute :"attachment#{i}_id", Integer
    %i[name size mime_type].each do |attr|
      attribute :"attachment#{i}_#{attr}", String
    end
  end
end
