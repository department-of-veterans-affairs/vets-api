# frozen_string_literal: true

module VBADocuments
  module Responses
    module TooManyRequestsError
      def self.extended(base)
        base.response 429 do
          key :description, 'Too many requests'
          content 'application/json' do
            schema do
              key :type, :object
              key :required, [:data]
              property :Message do
                key :type, :string
                key :description, 'message'
                key :example, 'API rate limit exceeded'
              end
            end
          end
        end
      end
    end
  end
end
