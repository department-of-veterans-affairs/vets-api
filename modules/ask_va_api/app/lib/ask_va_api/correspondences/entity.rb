# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Entity
      attr_reader :id,
                  :inquiry_id,
                  :message,
                  :modified_on,
                  :status_reason,
                  :description,
                  :enable_reply,
                  :attachment_names

      def initialize(info)
        @id = info[:id]
        @inquiry_id = info[:inquiryId]
        @message = info[:message_type]
        @modified_on = info[:modifiedon]
        @status_reason = info[:status_reason]
        @description = info[:description]
        @enable_reply = info[:enable_reply]
        @attachment_names = info[:attachmentNames]
      end
    end
  end
end
