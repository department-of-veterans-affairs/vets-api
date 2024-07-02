# frozen_string_literal: true

module Mobile
  module V0
    class MessageSerializer < MessagesSerializer
      include JSONAPI::Serializer

      set_type :messages

      has_many :attachments, serializer: Mobile::V0::AttachmentSerializer, &:attachments
    end
  end
end
