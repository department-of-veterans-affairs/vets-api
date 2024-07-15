# frozen_string_literal: true

class Swagger::V1::Requests::IvcChampvaForms
  include Swagger::Blocks

  swagger_path '/ivc_champva/v1/forms/status_updates' do
    operation :post do
      extend Swagger::Responses::AuthenticationError

      key :description, 'Updates an existing form'
      key :operationId, 'Endpoint for updating an existing form'
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
            key :example,
                ['12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
                 '12345678-1234-5678-1234-567812345678_vha_10_10d2.pdf']
          end
          property :status do
            key :type, :string
            key :example, 'Processed'
            key :description, 'Status of the form processing'
          end
          property :case_id do
            key :type, :string
            key :example, 'D-40350'
            key :description, 'PEGA System UUID'
          end
        end
      end
    end
  end
end
