# frozen_string_literal: true

module Swagger
  module Requests
    module Prescriptions
      class Prescriptions
        include Swagger::Blocks

        swagger_path '/v0/prescriptions' do
          operation :get do
            key :description, 'Get a list of active and inactive prescriptions'
            key :operationId, 'indexPrescriptions'
            key :tags, %w[prescriptions]

            parameter :optional_page_number
            parameter :optional_page_length
            parameter :optional_sort
            parameter :optional_filter

            response 200 do
              key :description, 'prescription index response'

              schema do
                key :'$ref', :Prescriptions
              end
            end
          end
        end

        swagger_path '/v0/prescriptions/active' do
          operation :get do
            key :description, 'Get a list of active prescriptions'
            key :operationId, 'indexActivePrescriptions'
            key :tags, %w[prescriptions]

            parameter :optional_page_number
            parameter :optional_page_length
            parameter :optional_sort

            response 200 do
              key :description, 'active prescription index response'

              schema do
                key :'$ref', :Prescriptions
              end
            end
          end
        end

        swagger_path '/v0/prescriptions/{id}' do
          operation :get do
            key :description, 'Get details about a prescription'
            key :operationId, 'showPrescriptions'
            key :tags, %w[prescriptions]

            parameter name: :id, in: :path, required: true, type: :integer, description: 'id of the presecription'

            response 200 do
              key :description, 'prescription show response'

              schema do
                key :'$ref', :Prescription
              end
            end

            response 404 do
              key :description, 'Record not available'

              schema do
                key :'$ref', :Errors
              end
            end
          end
        end

        swagger_path '/v0/prescriptions/{id}/refill' do
          operation :patch do
            key :description, 'refills a prescription'
            key :operationId, 'refillPrescriptions'
            key :tags, %w[prescriptions]

            parameter name: :id, in: :path, required: true, type: :integer, description: 'id of the presecription'

            response 204 do
              key :description, 'prescription refill response'
            end

            response 400 do
              key :description, 'prescription not refillable'

              schema do
                key :'$ref', :Errors
              end
            end

            response 404 do
              key :description, 'prescription not available'

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
