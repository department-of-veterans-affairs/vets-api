# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class InquiryCreator
      attr_reader :inquiry_number

      def initialize(inquiry_number:)
        @inquiry_number = inquiry_number
        @service = DynamicsService.new
        @reply_creator = Replies::ReplyCreator
      end

      def call
        reply = @reply_creator.new(inquiry_number:).call

        Inquiries::Inquiry.new(@service.get_inquiry(inquiry_number:), reply)
      end
    end
  end
end
