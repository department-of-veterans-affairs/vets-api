# frozen_string_literal: true

module Swagger
  module Responses
    module ForbiddenError
      def self.extended(base)
        base.response 403 do
          key :description, 'Forbidden'
          schema do
            key :$ref, :Errors
          end
        end
      end
    end
  end
end
