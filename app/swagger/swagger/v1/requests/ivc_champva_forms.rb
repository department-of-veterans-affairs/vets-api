# frozen_string_literal: true

class Swagger::V1::Requests::IvcChampvaForms
  include Swagger::Blocks

  swagger_path '/ivc_champva/v1/forms/status_updates' do
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
              key :description, 'List of file names associated with the form'
            end
            key :example, ['12345678-1234-5678-1234-567812345678_vha_7959F1.pdf', '12345678-1234-5678-1234-567812345678_vha_7959F2.pdf']
          end
          property :status do
            key :type, :string
            key :example, 'processed'
            key :description, 'Status of the form processing'
          end
        end
      end
    end
  end
end
