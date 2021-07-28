# frozen_string_literal: true

module VBADocuments
  module Responses
    module V2
      module UnexpectedError
        def self.extended(base)
          base.response 422 do
            key :description, 'Unprocessable Entity'
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
