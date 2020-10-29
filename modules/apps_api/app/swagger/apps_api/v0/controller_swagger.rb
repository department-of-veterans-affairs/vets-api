# frozen_string_literal: true

module AppsApi
  module V0
    class ControllerSwagger
      include Swagger::Blocks

      swagger_path 'apps' do
        operation :get do
          key :summary, 'All Applications'
          key :description, 'Returns all Applications currently onboarded to Va.gov'
          key :operationId, 'getAllApps'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Apps'
          ]
          response 200 do
            key :description, 'Directory index response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :AppsIndex
                end
              end
            end
          end
        end
      end
    end
  end
end
