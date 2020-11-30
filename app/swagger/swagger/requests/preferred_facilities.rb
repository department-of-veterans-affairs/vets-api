# frozen_string_literal: true

module Swagger
  module Requests
    class PreferredFacilities
      include Swagger::Blocks

      swagger_path '/v0/preferred_facilities' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, "Get list of user's preferred facilities"
          key :operationId, 'getPreferredFacilities'

          response 200 do
            key :description, "user's preferred facilities"

            schema do
              property :data, type: :array do
                items do
                  property :id, type: :string
                  property :type, type: :string
                  property :attributes, type: :object do
                    property :facility_code, type: :string
                  end
                end
              end
            end
          end
        end

        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Create a preferred facility for a user'
          key :operationId, 'createPreferredFacility'

          parameter do
            key :name, :preferred_facility
            key :in, :body
            key :description, 'Preferred Facility data'
            key :required, true

            schema do
              key :type, :object
              key :required, %i[preferred_facility]

              property :preferred_facility, type: :object do
                key :required, %i[facility_code]

                property :facility_code, type: :string
              end
            end
          end

          response 200 do
            key :description, 'the created preferred facility'

            schema do
              property :data, type: :object do
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  property :facility_code, type: :string
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/preferred_facilities/{id}' do
        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, "Destroy a user's preferred facility"
          key :operationId, 'deletePreferredFacility'

          response 200 do
            key :description, 'the destroyed preferred facility'

            schema do
              property :data, type: :object do
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  property :facility_code, type: :string
                end
              end
            end
          end
        end
      end
    end
  end
end
