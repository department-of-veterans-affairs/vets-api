# frozen_string_literal: true

module Swagger
  module Requests
    module IvcChampvaForms
      include Swagger::Blocks

      swagger_path '/v1/forms' do
        operation :post do
          key :summary, 'Creates a new form'
          key :description, 'Endpoint for creating a new form'
          key :tags, ['Forms']
          consumes 'application/json'
          parameter do
            key :name, :form_creation_body
            key :in, :body
            key :description, 'JSON payload containing form data'
            key :required, true
            schema do
              # Define schema for form creation payload
            end
          end

          response 201 do
            key :description, 'Form created successfully'
          end

          response 400 do
            key :description, 'Invalid request'
            schema do
              # Define schema for error response
            end
          end

          response 500 do
            key :description, 'Internal server error'
            schema do
              property :error_code do
                key :type, :string
                key :example, 'INTERNAL_SERVER_ERROR'
                key :description, 'Error code indicating internal server error'
              end
              property :error_message do
                key :type, :string
                key :example, 'An unexpected error occurred'
                key :description, 'Error message describing the issue'
              end
            end
          end
        end
      end

      swagger_path '/v1/forms/submit_supporting_documents' do
        operation :post do
          key :summary, 'Submits supporting documents for a form'
          key :description, 'Endpoint for submitting supporting documents for a form'
          key :tags, ['Forms']
          consumes 'multipart/form-data'
          parameter do
            key :name, :form_documents_body
            key :in, :formData
            key :type, :file
            key :description, 'Supporting document file(s) to submit'
            key :required, true
          end
          parameter do
            key :name, :form_id
            key :in, :query
            key :type, :string
            key :description, 'ID of the form to submit supporting documents for'
            key :required, true
          end

          response 200 do
            key :description, 'Supporting documents submitted successfully'
          end

          response 400 do
            key :description, 'Invalid request'
            schema do
              # Define schema for error response
            end
          end

          response 500 do
            key :description, 'Internal server error'
            schema do
              property :error_code do
                key :type, :string
                key :example, 'INTERNAL_SERVER_ERROR'
                key :description, 'Error code indicating internal server error'
              end
              property :error_message do
                key :type, :string
                key :example, 'An unexpected error occurred'
                key :description, 'Error message describing the issue'
              end
            end
          end
        end
      end
    end
  end
end
