# frozen_string_literal: true

module Swagger
  module Responses
    module RecordNotFoundError
      def self.extended(base)
        base.response 404 do
          key :description, 'Record not found'
          schema do
            key :$ref, :Errors
          end
        end
      end
    end
  end
end
