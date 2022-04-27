# frozen_string_literal: true

module MyHealth
  module V1
    class MessageSerializer < MessagesSerializer
      has_many :attachments, each_serializer: AttachmentSerializer
    end
  end
end
