# frozen_string_literal: true

module Swagger
  module Requests
    class PreferredFacilities
      include Swagger::Blocks

      swagger_path '/v0/preferred_facilities' do
        operation :get do
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
      end
    end
  end
end
