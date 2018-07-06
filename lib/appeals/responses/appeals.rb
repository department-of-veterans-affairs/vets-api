# frozen_string_literal: true

module Appeals
  module Responses
    class Appeals < Common::Base
      attribute :body, String
      attribute :status, Integer

      def initialize(body, status)
        self.body = body if json_format_is_valid?(body)
        self.status = status
      rescue JSON::Schema::ValidationError => error
        raise Common::Client::Errors::ClientError.new(error.message, 500)
      end

      private

      def json_format_is_valid?(body)
        JSON::Validator.validate!('spec/support/schemas/appeals.json', body, strict: true)
      end
    end
  end
end
