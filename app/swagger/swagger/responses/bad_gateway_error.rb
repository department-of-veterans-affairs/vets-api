# frozen_string_literal: true

module Swagger
  module Responses
    module BadGatewayError
      def self.extended(base)
        base.response 502 do
          key :description, 'Internal server error'
          schema do
            key :$ref, :Errors
          end
        end
      end
    end
  end
end
