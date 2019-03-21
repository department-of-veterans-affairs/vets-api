# frozen_string_literal: true

module Swagger
  module Requests
    class ServiceStatuses
      include Swagger::Blocks

      swagger_path '/v0/service_statuses' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets the current status of all external services'
          key :operationId, 'getServiceStatuses'
          key :tags, %w[service_statuses]

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
                      property :status,
                               type: :string,
                               enum: PagerDuty::Models::Service::STATUSES,
                               example: PagerDuty::Models::Service::ACTIVE
                      property :last_incident_timestamp,
                               type: %i[string null],
                               example: '2019-03-21T16:54:34.000Z'
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
    end
  end
end
