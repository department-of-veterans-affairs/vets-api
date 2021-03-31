# frozen_string_literal: true

module Swagger
  module Responses
    module SavedForm
      def self.extended(base)
        base.response 200 do
          key :description, 'Form Submitted'
          schema do
            key :$ref, :SavedForm
          end
        end
      end
    end
  end
end
