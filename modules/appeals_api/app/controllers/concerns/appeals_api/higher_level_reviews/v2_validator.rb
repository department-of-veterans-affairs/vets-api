# frozen_string_literal: true

module AppealsApi
  module HigherLevelReviews
    class V2Validator
      def initialize(request_body, request_headers)
        @request_body = request_body
        @request_headers = request_headers
      end

      def validate!
        [true, nil] # valid, error_message
      end

      private

      attr_accessor :request_body, :request_headers
    end
  end
end
