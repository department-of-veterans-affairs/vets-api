# frozen_string_literal: true

module VBADocuments
  module Responses
    module UnauthorizedError
      def self.extended(base)
        base.response 401 do
          key :description, 'Unauthorized request'
          content 'application/json' do
            schema do
              key :type, :object
              key :required, [:data]
              property :Message do
                key :type, :string
                key :description, 'Error detail'
                key :example, 'Unauthorized Request'
              end
            end
          end
        end
      end
    end
  end
end
