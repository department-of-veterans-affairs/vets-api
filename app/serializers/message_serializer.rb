# frozen_string_literal: true
class MessageSerializer < ActiveModel::Serializer
  # Alias id to folder_id to keep consistent with other model naming conventions
  attribute(:message_id) { object.id }

  attribute :id
  attribute :category
  attribute :subject
  attribute :body
  attribute :attachment
  attribute :sent_date
  attribute :sender_id
  attribute :sender_name
  attribute :recipient_id
  attribute :recipient_name
  attribute :read_receipt
end
