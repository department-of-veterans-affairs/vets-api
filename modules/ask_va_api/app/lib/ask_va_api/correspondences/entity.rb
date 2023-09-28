# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Entity
      attr_reader :id,
                  :inquiry_number,
                  :correspondence

      def initialize(info)
        @id = info[:replyId]
        @inquiry_number = info[:inquiryNumber]
        @correspondence = info[:reply]
      end
    end
  end
end
