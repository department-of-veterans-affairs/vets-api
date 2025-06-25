# frozen_string_literal: true

module Mulesoft
  module PreNeed
    class Response < Common::Base
      attr_accessor :status, :body

      def self.from(raw_response)
        new(
          status: raw_response.status,
          body: raw_response.body
        )
      end
    end
  end
end
