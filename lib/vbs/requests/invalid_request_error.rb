# frozen_string_literal: true

module VBS
  module Requests
    class InvalidRequestError < StandardError
      attr_accessor :errors

      def initialize(json_schema_errors)
        @errors = json_schema_errors
        message = json_schema_errors.pluck(:message)
        super(message)
      end
    end
  end
end
