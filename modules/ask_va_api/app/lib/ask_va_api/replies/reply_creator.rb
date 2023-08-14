# frozen_string_literal: true

module AskVAApi
  module Replies
    class ReplyCreator
      attr_reader :inquiry_number

      def initialize(inquiry_number:)
        @inquiry_number = inquiry_number
        @service = DynamicsService.new
      end

      def call
        Replies::Reply.new(@service.get_reply(inquiry_number:))
      end
    end
  end
end
