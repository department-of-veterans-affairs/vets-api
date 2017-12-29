# frozen_string_literal: true
module Swagger
  module Requests
    class MaintenanceWindows
      include Swagger::Blocks

      swagger_path '/v0/maintenance_windows' do
        operation :get do
          key :description, 'Get a list of scheduled maintenance windows by service'
          key :operationId, 'getMaintenanceWindows'
          key :tags, [
            'maintenance_windows'
          ]

          response 200 do
            key :description, 'get list of scheduled maintenance windows'

            schema do
              key :'$ref', :MaintenanceWindows
            end
          end
        end
      end
    end
  end
end
