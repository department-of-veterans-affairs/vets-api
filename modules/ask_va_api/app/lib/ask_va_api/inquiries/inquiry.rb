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
                  :last_update

      def initialize(info)
        @id = nil
        @inquiry_number = info[:inquiryNumber]
        @attachments = info[:attachments]
        @topic = info[:inquiryTopic]
        @question = info[:submitterQuestions]
        @processing_status = info[:inquiryProcessingStatus]
        @last_update = info[:lastUpdate]
      end
    end
  end
end
