# frozen_string_literal: true

module Swagger
  module Responses
    module UnprocessableEntityError
      def self.extended(base)
        base.response 422 do
          key :description, 'Unprocessable Entity'
          schema do
            key :'$ref', :Errors
          end
        end
      end
    end
  end
end
