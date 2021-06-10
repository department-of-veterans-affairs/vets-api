# frozen_string_literal: true

module VBADocuments
  module V1
    module Responses
      module UnexpectedError
        def self.extended(base)
          base.response 422 do
            key :description, 'Forbidden'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :ErrorModel
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
