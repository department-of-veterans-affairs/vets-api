# frozen_string_literal: true

module Swagger
  module Requests
    class BenefitsReferenceData
      include Swagger::Blocks

      swagger_path '/v0/benefits_reference_data/{path}' do
        operation :get do
          key :description,
              'Get data from the Lighthouse Benefits Reference Data (BRD) End-point.'
          key :operationId, 'getBenefitsReferenceData'
          key :tags, %w[benefits_reference_data]

          parameter :optional_authorization

          parameter do
            key :name, :path
            key :in, :path
            key :description, 'The path/end-point to get data from the Lighthouse Benefits Reference Data (BRD) api'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, %i[totalItems totalPages links items]
              property :totalItems, type: :integer
              property :totalPages, type: :integer
              property :links, type: :array
              property :items, type: :array
            end
          end
        end
      end
    end
  end
end
