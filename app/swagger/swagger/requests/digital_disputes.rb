# frozen_string_literal: true

module Swagger
  module Requests
    class DigitalDisputes
      include Swagger::Blocks

      swagger_path '/debts_api/v0/digital_disputes' do
        operation :post do
          key :summary, 'Submits digital dispute documents to the Debt Management Center and VBS'
          key :description, "Submits PDF documents for debt disputes to the Debt Management Center.
            Veterans can upload one or more PDF files containing documentation supporting
            their dispute of a debt."
          key :operationId, 'postDigitalDispute'
          key :tags, %w[digital_disputes]
          key :consumes, ['multipart/form-data']

          parameter do
            key :name, 'files[]'
            key :in, :formData
            key :description, 'One or more PDF files (maximum 1MB each)'
            key :required, true
            key :type, :file
          end

          response 200 do
            key :description, 'Digital dispute successful submission'

            schema do
              property :message, type: :string
            end
          end
        end
      end
    end
  end
end
