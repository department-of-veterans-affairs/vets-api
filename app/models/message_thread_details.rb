# frozen_string_literal: true

require 'common/models/attribute_types/date_time_string'

class MessageThreadDetails < Message
  attribute :message_id, Integer
  attribute :thread_id, Integer
  attribute :folder_id, Integer
  attribute :message_body, String
  attribute :draft_date, Common::DateTimeString
  attribute :to_date, Common::DateTimeString
  attribute :has_attachments, Boolean
  (1..4).each do |i|
    %i[id name size mime_type].each do |attr|
      attribute :"attachment#{i}_#{attr}"
    end
  end
end
