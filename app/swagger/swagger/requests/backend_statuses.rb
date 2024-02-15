# frozen_string_literal: true

require 'backend_services'
require 'pagerduty/models/service'

module Swagger
  module Requests
    class BackendStatuses
      include Swagger::Blocks

      swagger_path '/v0/backend_statuses' do
        operation :get do
          key :description, 'Gets the current status of all external services'
          key :operationId, 'getBackendStatuses'
          key :tags, %w[backend_statuses]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, %i[data]
              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  key :required, %i[reported_at statuses]
                  property :reported_at,
                           type: :string,
                           description: "The time from the call to PagerDuty's API",
                           example: '2019-03-21T16:54:34.000Z'
                  property :statuses do
                    key :type, :array
                    items do
                      property :service, type: :string, example: 'Appeals'
                      property :service_id, type: :string, example: 'appeals'
                      property :status,
                               type: :string,
                               enum: PagerDuty::Models::Service::STATUSES,
                               example: PagerDuty::Models::Service::ACTIVE
                      property :last_incident_timestamp,
                               type: %i[string null],
                               example: '2019-03-21T16:54:34.000Z'
                    end
                  end
                  property :maintenance_windows do
                    key :type, :array
                    items do
                      property :id, type: :integer, example: 1
                      property :external_service, type: :string, example: 'idme'
                      property :start_time,
                               type: :string,
                               description: 'The start time of the maintenance window',
                               example: '2024-02-17T09:00:00.000Z'
                      property :end_time,
                               type: :string,
                               description: 'The end time of the maintenance window',
                               example: '2024-02-17T10:00:00.000Z'
                      property :description,
                               type: :string,
                               description: 'The description of the maintenance window',
                               example: 'ID.me will be down for maintenance'
                    end
                  end
                end
              end
            end
          end

          response 429 do
            key :description, 'Exceeded rate limit'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status]
                  property :title, type: :string, example: 'Exceeded rate limit'
                  property :detail,
                           type: :string,
                           example: "Exceeded PagerDuty's API rate limit"
                  property :code, type: :string, example: 'PAGERDUTY_429'
                  property :status, type: :string, example: '429'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/backend_statuses/{service}' do
        operation :get do
          key :description, 'Gets the status of backend service'
          key :operationId, 'getBackendStatus'
          key :tags, %w[backend_statuses]

          parameter do
            key :name, 'service'
            key :in, :path
            key :description, 'The name of the backend service'
            key :required, true
            key :type, :string
            key :enum, BackendServices.all
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :Availability
            end
          end
        end
      end

      swagger_schema :Availability do
        key :required, %i[data]
        property :data, type: :object do
          key :required, %i[attributes]
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            key :required, %i[name is_available]
            property :is_available, type: :boolean, example: true
            property :name, type: :string, example: 'gibs'
          end
        end
      end
    end
  end
end
