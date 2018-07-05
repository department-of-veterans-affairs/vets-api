# frozen_string_literal: true

module Swagger
  module Requests
    class ServiceInformation
      include Swagger::Blocks

      swagger_path '/v0/service_information' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of all service periods and whether
                             they have served in a combat zone for the user'
          key :operationId, 'getServiceInformation'
          key :tags, %w[form_526]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :ServiceInfo
            end
          end
        end
      end

      swagger_schema :ServiceInfo do
        key :required, %i[data]
        property :data, type: :object do
          key :required, %i[attributes]
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            key :required, %i[service_periods served_in_combat_zone]
            property :served_in_combat_zone, type: :boolean, example: true
            property :service_periods, type: :array do
              items do
                key :required, %i[service_branch date_range]
                property :service_branch, type: :string, example: 'Air Force Reserve'
                property :date_range, type: :object do
                  key :required, %i[from to]
                  property :from, type: :string, example: '2007-04-01'
                  property :to, type: :string, example: '2016-06-01'
                end
              end
            end
          end
        end
      end
    end
  end
end
