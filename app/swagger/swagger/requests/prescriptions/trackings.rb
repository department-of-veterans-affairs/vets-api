# frozen_string_literal: true

module Swagger
  module Requests
    module Prescriptions
      class Trackings
        include Swagger::Blocks

        swagger_path '/v0/prescriptions/{prescription_id}/trackings' do
          operation :get do
            key :description, 'ship tracking information for prescription'
            key :operationId, 'trackPrescriptions'
            key :tags, %w[prescriptions]

            parameter name: :prescription_id, in: :path, required: true,
                      type: :integer, description: 'id of the presecription'

            response 200 do
              key :description, 'prescription tracking response'

              schema do
                key :'$ref', :Trackings
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
