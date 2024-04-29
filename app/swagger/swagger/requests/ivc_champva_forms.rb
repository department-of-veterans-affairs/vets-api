# frozen_string_literal: true

module Swagger
  module Requests
    module IvcChampvaForms
      include Swagger::Blocks

      swagger_path '/v0/ivc_champva_forms/status_updates' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates a new form'
          key :operationId, 'Endpoint for creating a new form'
          key :tags, %w[ivc_champva_forms]
          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
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
                  key :example, ['12345678-1234-5678-1234-567812345678_vha_10_10d-tmp.pdf', '12345678-1234-5678-1234-567812345678_vha10_10d_2-tmp.pdf']
                  key :description, 'List of file names associated with the form'
                end
              end
              property :status do
                key :type, :string
                key :enum, ['pending', 'processing', 'processed']
                key :example, 'processed'
                key :description, 'Status of the form processing'
              end
            end
          end

          response 400 do
            key :description, 'Invalid request'
            schema do
              key :type, :object
              property :errors do
                key :type, :string
                key :format, :string
                key :example, 'Received a bad request response from the upstream server'
                key :description, '400 error'
              end
              property :status do
                key :type, :string
                key :enum, ['pending', 'processing', 'processed','error']
                key :example, 'Invalid request'
                key :description, 'Status of the form processing'
              end
            end
          end

          response 500 do
            key :description, 'Internal server error'
            schema do
              key :type, :object
              property :form_uuid do
                key :type, :string
                key :format, :string
                key :example, 'Temporary connectivity issues. Please try again'
                key :description, '500 error'
              end
              property :status do
                key :type, :string
                key :enum, ['pending', 'processing', 'processed']
                key :example, 'Internal server error'
                key :description, 'Status of the form processing'
              end
            end
          end
        end
      end
    end
  end
end
