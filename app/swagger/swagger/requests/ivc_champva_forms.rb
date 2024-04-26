# frozen_string_literal: true

module Swagger
  module Requests
    module IvcChampvaForms
      include Swagger::Blocks

      swagger_path '/v0/ivc_champva_forms/status_updates' do
        operation :post do
          key :summary, 'Endpoint to receive status updates for IVC ChampVA forms'
          key :consumes, ['application/json']
          key :produces, ['application/json']
          parameter do
            key :name, :payload
            key :in, :body
            key :description, 'JSON payload containing form UUID, file names, and status'
            key :required, true
            schema do
              key :type, :object
              property :form_uuid do
                key :type, :string
                key :format, :uuid
                key :example, '12345678-1234-5678-1234-567812345678'
                key :description, 'UUID of the form'
              end
              property :file_names do
                key :type, :array
                items do
                  key :type, :string
                  key :example, ['file1.pdf', 'file2.pdf']
                  key :description, 'List of file names associated with the form'
                end
              end
              property :status do
                key :type, :string
                key :example, 'processed'
                key :description, 'Status of the form processing'
              end
            end
          end
          response 200 do
            key :description, 'Successful response'
            schema do
              key :type, :object
              property :status do
                key :type, :integer
                key :example, 200
                key :description, 'HTTP status code indicating success'
              end
            end
          end
          response 500 do
            key :description, 'Error response'
            schema do
              key :type, :object
              property :status do
                key :type, :integer
                key :example, 500
                key :description, 'HTTP status code indicating error'
              end
              property :error do
                key :type, :string
                key :example, 'error'
                key :description, 'Error message describing the issue'
              end
            end
          end
        end
      end
    end
  end
end
