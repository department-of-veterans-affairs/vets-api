# frozen_string_literal: true

module AskVAApi
  module Users
    class UserInquiries
      attr_reader :id,
                  :inquiries

      def initialize(inquiries)
        @id = nil
        @inquiries = inquiries
      end
    end
  end
end
