# frozen_string_literal: true

class MessagesSerializer < ActiveModel::Serializer
  attribute :id

  attribute(:message_id) { object.id }
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

  link(:self) { v0_message_url(object.id) }
end
