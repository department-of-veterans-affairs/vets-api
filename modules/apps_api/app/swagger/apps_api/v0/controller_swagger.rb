# frozen_string_literal: true

module AppsApi
  module V0
    class ControllerSwagger
      include Swagger::Blocks

      swagger_path 'directory' do
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
      swagger_path 'directory/scopes/{service_category}' do
        operation :get do
          key :summary, 'Scopes'
          key :description, 'Returns all scopes currently available to a given service category'
          key :operationId, 'getScopes'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Apps'
          ]
          response 200 do
            key :description, 'Scope response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :Scopes
                end
              end
            end
          end
          response 204 do
            key :description, 'Empty scope response'
          end
        end
      end
    end
  end
end
