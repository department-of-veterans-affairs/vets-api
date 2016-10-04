# frozen_string_literal: true
class MessageSerializer < ActiveModel::Serializer
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

  has_many :attachments, each_serializer: AttachmentSerializer

  link(:self) { v0_message_url(object.id) }
end
