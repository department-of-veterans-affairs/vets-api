# frozen_string_literal: true

module Appeals
  module Responses
    class Appeals < Common::Base
      attribute :body, String
      attribute :status, Integer

      def initialize(body, status)
        self.body = body
        self.status = status
      end
    end
  end
end
