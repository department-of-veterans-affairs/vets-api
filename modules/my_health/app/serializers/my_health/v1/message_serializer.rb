# frozen_string_literal: true

module MyHealth
  module V1
    class MessageSerializer < MessagesSerializer
      include JSONAPI::Serializer

      set_type :messages

      has_many :attachments, serializer: AttachmentSerializer, &:attachments
    end
  end
end
