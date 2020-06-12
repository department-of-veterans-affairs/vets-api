# frozen_string_literal: true

module Swagger
  module Responses
    module AuthenticationError
      def self.extended(base)
        base.response 401 do
          key :description, 'Not authorized'
          schema do
            key :'$ref', :Errors
          end
        end
      end
    end
  end
end
