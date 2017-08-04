# frozen_string_literal: true
module Swagger
  module Requests
    module BB
      class HealthRecords
        include Swagger::Blocks

        swagger_path '/v0/health_records/refresh' do
          operation :get do
            key :description, 'Retrieves patient status'
            key :operationId, 'bbHealthRecordsRefresh'
            key :tags, %w(bb health-records refresh)

            response 200 do
              key :description, 'health records refresh response'

              schema do
                key :'$ref', :HealthRecordsRefresh
              end
            end
          end
        end
      end
    end
  end
end
