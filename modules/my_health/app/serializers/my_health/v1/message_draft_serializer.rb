# frozen_string_literal: true

module MyHealth
  module V1
    class MessageDraftSerializer < MessageSerializer
      include JSONAPI::Serializer

      set_type :message_drafts
    end
  end
end
