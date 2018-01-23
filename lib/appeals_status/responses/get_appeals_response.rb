# frozen_string_literal: true

module AppealsStatus
  module Responses
    class GetAppealsResponse
      attr_accessor :status
      attr_accessor :appeals

      def initialize(status:, appeals:)
        @status = status
        @appeals = appeals
      end
    end
  end
end
