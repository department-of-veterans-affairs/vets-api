# frozen_string_literal: true

class MessageSerializer < MessagesSerializer
  has_many :attachments, each_serializer: AttachmentSerializer
end
