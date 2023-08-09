# frozen_string_literal: true

module AskVAApi
  module Inquiry
    class Creator
      attr_reader :inquiry_number,
                  :topic,
                  :question,
                  :processing_status,
                  :last_update,
                  :id

      def initialize(info)
        @id = nil
        @inquiry_number = info['inquiryNumber']
        @topic = info['inquiryTopic']
        @question = info['submitterQuestions']
        @processing_status = info['inquiryProcessingStatus']
        @last_update = info['lastUpdate']
      end
    end
  end
end
