# frozen_string_literal: true

module AskVAApi
  module Users
    class UserInquiriesCreator
      attr_reader :uuid

      def initialize(uuid:)
        @uuid = uuid
        @service = DynamicsService.new
      end

      def call
        inquiries = @service.get_user_inquiries(uuid:).map do |inquiry|
          Inquiries::Inquiry.new(inquiry.except(:attachments))
        end

        UserInquiries.new(inquiries)
      end
    end
  end
end
