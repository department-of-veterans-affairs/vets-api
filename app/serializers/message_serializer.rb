# frozen_string_literal: true
class MessageSerializer < ActiveModel::Serializer
  def id
    object.message_id
  end

  attribute :message_id
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

  link(:self) { v0_message_url(object.message_id) }
end
