# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Entity
      attr_reader :id,
                  :message_type,
                  :modified_on,
                  :status_reason,
                  :description,
                  :enable_reply,
                  :attachments

      def initialize(info)
        @id = info[:Id]
        @message_type = info[:MessageType]
        @modified_on = info[:ModifiedOn]
        @status_reason = info[:StatusReason]
        @description = info[:Description]
        @enable_reply = info[:EnableReply]
        @attachments = info[:AttachmentNames]
      end
    end
  end
end
