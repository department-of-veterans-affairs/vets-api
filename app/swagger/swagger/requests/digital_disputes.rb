# frozen_string_literal: true

module Swagger
  module Requests
    class DigitalDisputes
      include Swagger::Blocks

      swagger_path '/debts_api/v0/digital_disputes' do
        operation :post do
          key :summary, 'Submits a digital dispute PDF to the Debt Management Center'
          key :description, "Submits a digital dispute PDF file to the Debt Management Center.
            The veteran uploads a completed dispute form as a PDF, which will be forwarded
            to the DMC for processing."
          key :operationId, 'postDigitalDispute'
          key :tags, %w[digital_disputes]
          key :consumes, ['multipart/form-data']

          parameter do
            key :name, :files
            key :in, :formData
            key :description, 'PDF files to upload'
            key :required, true
            key :type, :file
          end

          response 200 do
            key :description, 'Digital dispute PDFs successfully received'

            schema do
              property :message, type: :string,
                                 description: 'Success message'
            end
          end

          response 422 do
            key :description, 'Unprocessable entity - validation errors'

            schema do
              property :errors, type: :object do
                property :files, type: :array do
                  items do
                    key :type, :string
                    key :description, 'Error message for the files field'
                  end
                end
              end
            end
          end

          response 500 do
            key :description, 'Internal server error'

            schema do
              property :errors, type: :object do
                property :base, type: :array do
                  items do
                    key :type, :string
                    key :description, 'General error message'
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
