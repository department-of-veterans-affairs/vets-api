# frozen_string_literal: true

module Swagger
  module Responses
    module PayloadTooLargeError
      def self.extended(base)
        base.response 413 do
          key :description, 'PayloadTooLarge'
          schema do
            key :'$ref', :Errors
          end
        end
      end
    end
  end
end
