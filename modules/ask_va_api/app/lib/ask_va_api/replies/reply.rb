# frozen_string_literal: true

module AskVAApi
  module Replies
    class Reply
      attr_reader :id,
                  :inquiry_number,
                  :reply

      def initialize(info)
        @id = info[:replyId]
        @inquiry_number = info[:inquiryNumber]
        @reply = info[:reply]
      end
    end
  end
end
