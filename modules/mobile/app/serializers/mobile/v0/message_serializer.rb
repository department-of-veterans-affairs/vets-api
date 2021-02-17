# frozen_string_literal: true

module Mobile
  module V0
    class MessageSerializer < MessagesSerializer
      has_many :attachments, each_serializer: AttachmentSerializer
    end
  end
end
