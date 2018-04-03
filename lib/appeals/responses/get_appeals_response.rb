# frozen_string_literal: true

module Appeals
  module Responses
    class GetAppealsResponse
      attr_accessor :status
      attr_accessor :appeal_series

      def initialize(status:, appeal_series:)
        @status = status
        @appeal_series = appeal_series
      end
    end
  end
end
