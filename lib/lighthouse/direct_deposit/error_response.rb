# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    class ErrorResponse
      attr_accessor :status, :errors

      def initialize(status, errors)
        @status = status
        @errors = errors || []
      end

      def response
        {
          status: @status,
          body:
        }
      end

      def body
        { errors: @errors }
      end

      def code
        errors.first[:code]
      end

      def title
        errors.first[:title]
      end

      def detail
        errors.first[:detail]
      end

      def message
        "#{code}: #{title} - #{detail}"
      end

      def error?
        true
      end
    end
  end
end
