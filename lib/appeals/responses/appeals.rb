# frozen_string_literal: true

module Appeals
  module Responses
    class Appeals < Common::Base
      attribute :body, String
      attribute :status, Integer

      def initialize(body, status)
        self.status = status
        if self.status == 404
          self.body = { 'data' => [] }
        elsif json_format_is_valid?(body)
          self.body = body
        end
      end

      private

      def json_format_is_valid?(body)
        JSON::Validator.validate!('lib/appeals/schema/appeals.json', body, strict: true)
      end
    end
  end
end
