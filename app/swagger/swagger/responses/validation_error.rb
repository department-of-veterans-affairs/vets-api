# frozen_string_literal: true

module Swagger
  module Responses
    module ValidationError
      def self.extended(base)
        base.response 422 do
          key :description, 'Failed model validation(s)'
          schema do
            key :$ref, :Errors
          end
        end
      end
    end
  end
end
