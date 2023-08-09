# frozen_string_literal: true

module AskVAApi
  module UserInquiries
    class Creator
      attr_reader :id,
                  :inquiries

      def initialize(inquiries)
        @id = nil
        @inquiries = inquiries
      end
    end
  end
end
