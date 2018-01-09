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
            key :tags, %w[bb health-records refresh]

            response 200 do
              key :description, 'health records refresh response'

              schema do
                key :'$ref', :HealthRecordsRefresh
              end
            end

            response 403 do
              key :description, 'forbidden user'

              schema do
                key :'$ref', :Errors
              end
            end
          end
        end

        swagger_path '/v0/health_records/eligible_data_classes' do
          operation :get do
            key :description, 'Retrieves a list of health care record categories'
            key :operationId, 'bbHealthRecordsEligibleDataClasses'
            key :tags, %w[bb health-records eligible classes]

            response 200 do
              key :description, 'heath records eligible data classes list'

              schema do
                key :'$ref', :HealthRecordsEligibleDataClasses
              end
            end
          end
        end

        swagger_path '/v0/health_records' do
          operation :get do
            key :description, 'Retrieves a BB Report'
            key :operationId, 'bbHealthRecordsShow'
            key :tags, %w[bb health-records show]

            parameter name: :doc_type, in: :query, required: false,
                      type: :string, enum: %i[txt pdf], description: 'the document type'

            response 200 do
              key :description, 'health records show response'

              schema do
                key :type, :file
              end
            end

            response 503 do
              key :description, 'health records backend error response'

              schema do
                key :'$ref', :Errors
              end
            end
          end

          operation :post do
            key :description, 'Generates a new BB Report'
            key :operationId, 'bbHealthRecordsCreate'
            key :tags, %w[bb health-records create]

            parameter name: :nil, in: :body do
              schema do
                key :required, %i[from_date to_date data_classes]

                property :from_date, type: :string, description: 'date on which records start'
                property :to_date, type: :string, description: 'date on which records end'
                property :data_classes, type: :array, description: 'list of data to be returned' do
                  items do
                    key :type, :string
                  end
                end
              end
            end

            response 202 do
              key :description, 'health records create response'
            end

            response 422 do
              key :description, 'health records missing required parameter response'

              schema do
                key :'$ref', :Errors
              end
            end
          end
        end
      end
    end
  end
end
