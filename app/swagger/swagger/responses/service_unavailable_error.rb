# frozen_string_literal: true

module Swagger
  module Responses
    module ServiceUnavailableError
      def self.extended(base)
        base.response 503 do
          key :description, 'Internal server error'
          schema do
            key :$ref, :Errors
          end
        end
      end
    end
  end
end
