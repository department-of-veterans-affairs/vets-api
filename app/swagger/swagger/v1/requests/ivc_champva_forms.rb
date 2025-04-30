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

      parameter do
        key :name, :form_uuid
        key :description, 'UUID of the form'
        key :in, :body
        key :required, true

        schema do
          key :type, :string
          key :format, :uuid
          key :example, '12345678-1234-5678-1234-567812345678'
        end
      end

      parameter do
        key :name, :file_names
        key :description, 'List of file names associated with the form'
        key :in, :body
        key :required, true

        schema do
          key :type, :array
          items do
            key :type, :string
          end
          key :example,
              ['12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
               '12345678-1234-5678-1234-567812345678_vha_10_10d2.pdf']
        end
      end

      parameter do
        key :name, :status
        key :description, 'Status of the form processing'
        key :in, :body
        key :required, true

        schema do
          key :type, :string
          key :enum, ['Processed', 'Not Processed']
          key :example, 'Processed'
        end
      end

      parameter do
        key :name, :case_id
        key :description, 'PEGA System UUID'
        key :in, :body
        key :required, true

        schema do
          key :type, :string
          key :example, 'D-40350'
        end
      end

      response 200 do
        key :description, 'Response is OK'
      end
    end
  end
end
