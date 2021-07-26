# frozen_string_literal: true

module VBADocuments
  module Responses
    module ForbiddenError
      def self.extended(base)
        base.response 403 do
          key :description, 'Forbidden'
          content 'application/json' do
            schema do
              key :type, :object
              key :required, [:data]
              property :Message do
                key :type, :string
                key :description, 'Error detail'
                key :example, 'Invalid authentication credentials'
              end
            end
          end
        end
      end
    end
  end
end
