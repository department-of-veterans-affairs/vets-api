# frozen_string_literal: true

require 'backend_services'

module Swagger
  module Requests
    class FeatureToggles
      include Swagger::Blocks

      swagger_path '/v0/feature_toggles' do
        operation :get do
          key :description, 'Gets the current status of feature toggles'
          key :operationId, 'getFeatureToggless'
          key :tags, %w[site]

          parameter :optional_authorization
          parameter do
            key :name, :features
            key :description, 'A comma delimited list of the feature toggle names in snake or camel case'
            key :in, :path
            key :type, :string
            key :required, true
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, %i[data]
              property :data, type: :object do
                key :required, %i[features]
                property :features, type: :array do
                  items do
                    key :required, %i[code title user_preferences]
                    property :name, type: :string, example: 'facility_locator'
                    property :value, type: :boolean
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
