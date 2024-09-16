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
              'Successfully checked for Power of Attorney information. Returns Power of Attorney details if available; otherwise, returns an empty object.'
          content 'application/json' do
            schema do
              property :data do
                key :type, :object
                property :id do
                  key :type, :string
                  key :example, '123456'
                end
                property :type do
                  key :type, :string
                  key :description,
                      'Specifies the category of Power of Attorney (POA) representation. This field differentiates between two primary forms of POA: veteran_service_representatives and veteran_service_organizations.'
                  key :enum, %w[veteran_service_representatives veteran_service_organizations]
                end
                property :attributes do
                  key :type, :object
                  property :type do
                    key :type, :string
                    key :example, 'organization'
                    key :description, 'Type of Power of Attorney representation'
                    key :enum, %w[organization representative]
                  end
                  property :name do
                    key :type, :string
                    key :example, 'Veterans Association'
                  end
                  property :address_line1 do
                    key :type, :string
                    key :example, '1234 Freedom Blvd'
                  end
                  property :city do
                    key :type, :string
                    key :example, 'Arlington'
                  end
                  property :state_code do
                    key :type, :string
                    key :example, 'VA'
                  end
                  property :zip_code do
                    key :type, :string
                    key :example, '22204'
                  end
                  property :phone do
                    key :type, :string
                    key :example, '555-1234'
                  end
                  property :email do
                    key :type, :string
                    key :example, 'contact@example.org'
                  end
                end
              end
            end
          end
          content 'application/json' do
            schema do
              key :type, :object
              key :description, 'An empty JSON object indicating no Power of Attorney exists.'
              key :example, {}
            end
          end
        end

        response 404 do
          key :description, 'Resource not found'
          content 'application/json' do
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
        end

        response 500 do
          key :description, 'Unexpected server error'
          content 'application/json' do
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
end
