# frozen_string_literal: true

class MessageSerializer < MessagesSerializer
  include JSONAPI::Serializer

  set_type :messages

  has_many :attachments, serializer: AttachmentSerializer, &:attachments
end
