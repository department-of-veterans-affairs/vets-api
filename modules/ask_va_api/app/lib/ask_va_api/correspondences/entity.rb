# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Entity
      attr_reader :id,
                  :created_on,
                  :modified_on,
                  :status_reason,
                  :description,
                  :message_type,
                  :enable_reply,
                  :attachments

      def initialize(info)
        @id = info[:Id]
        @created_on = info[:CreatedOn]
        @modified_on = info[:ModifiedOn]
        @status_reason = info[:StatusReason]
        @description = info[:Description]
        @message_type = info[:MessageType]
        @enable_reply = info[:EnableReply]
        @attachments = info[:AttachmentNames]
      end
    end
  end
end
