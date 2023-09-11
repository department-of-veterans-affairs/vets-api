# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class Inquiry
      attr_reader :id,
                  :inquiry_number,
                  :attachments,
                  :topic,
                  :question,
                  :processing_status,
                  :last_update,
                  :reply

      def initialize(info, reply = nil)
        @id = nil
        @inquiry_number = info[:inquiryNumber]
        @attachments = info[:attachments]
        @topic = info[:inquiryTopic]
        @question = info[:submitterQuestions]
        @processing_status = info[:inquiryProcessingStatus]
        @last_update = info[:lastUpdate]
        @reply = reply
      end
    end
  end
end
