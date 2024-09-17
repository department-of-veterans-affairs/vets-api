# frozen_string_literal: true

module Requests
  class PowerOfAttorney
    include Swagger::Blocks

    swagger_path '/representation_management/v0/power_of_attorney' do
      operation :get do
        key :summary, 'Get Power of Attorney'
        key :description, 'Retrieves the Power of Attorney for a veteran, if any.'
        key :operationId, 'getPowerOfAttorney'
        key :tags, ['Power of Attorney']

        response 200 do
          key :description,
              'Successfully checked for Power of Attorney information. ' \
              'Returns Power of Attorney details if available; otherwise, ' \
              'returns an empty object.'
          schema do
            key :$ref, :PowerOfAttorneyResponse
          end
        end

        response 404 do
          key :description, 'Resource not found'
          schema do
            key :type, :object
            property :errors do
              key :type, :array
              items do
                key :type, :object
                property :title do
                  key :type, :string
                  key :example, 'Resource not found'
                end
                property :detail do
                  key :type, :string
                  key :example, 'Resource not found'
                end
                property :code do
                  key :type, :string
                  key :example, '404'
                end
                property :status do
                  key :type, :string
                  key :example, '404'
                end
              end
            end
          end
        end

        response 500 do
          key :description, 'Unexpected server error'
          schema do
            key :type, :object
            property :errors do
              key :type, :object
              property :title do
                key :type, :string
                key :example, 'Internal server error'
              end
              property :detail do
                key :type, :string
                key :example, 'Unexpected error occurred'
              end
              property :code do
                key :type, :string
                key :example, '500'
              end
              property :status do
                key :type, :string
                key :example, '500'
              end
            end
          end
        end
      end
    end
  end
end
