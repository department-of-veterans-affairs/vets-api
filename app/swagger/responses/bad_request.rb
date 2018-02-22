# frozen_string_literal: true

module Swagger
  module Responses
    module BadRequest
      def self.extended(base)
        base.response 400 do
          key :description, 'Bad Request'
          schema do
            key :'$ref', :Errors
          end
        end
      end
    end
  end
end
