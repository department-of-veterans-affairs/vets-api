# frozen_string_literal: true

module Swagger
  module Requests
    class MedicalCopays
      include Swagger::Blocks

      swagger_path '/v0/medical_copays' do
        operation :get do
          key :description, 'List of user copays for VA facilities'
          key :operationId, 'getMedicalCopays'
          key :tags, %w[medical_copays]

          response 200 do
            key :description, 'Successful copays lookup'
            schema do
              key :required, %i[data status]
              property :data, type: :array
              property :status, type: :integer, example: 200
            end
          end
        end
      end
    end
  end
end
