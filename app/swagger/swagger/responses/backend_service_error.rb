# frozen_string_literal: true

module Swagger
  module Responses
    module BackendServiceError
      def self.extended(base)
        base.response 400 do
          key :description, 'Backend service error'
          schema do
            key :'$ref', :Errors
          end
        end
      end
    end
  end
end
