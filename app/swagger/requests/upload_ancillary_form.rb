# frozen_string_literal: true

module Swagger
  module Requests
    class UploadAncillaryForm
      include Swagger::Blocks

      swagger_path '/v0/upload_ancillary_form' do
        operation :post do
          key :description, 'Upload a pdf or image file containing an ancillary form'
          key :operationId, 'uploadAncillaryForm'
          key :tags, %w[form_526]

          parameter do
            key :name, :ancillary_form_attachment
            key :description, 'Object containing file name'
            key :required, true

            parameter do
              key :name, :file_data
              key :description, 'The file path'
              key :required, true
            end
          end

          response 200 do
            key :description, 'Response is ok'
            schema do
              property :id, type: :integer, example: 272
              property :created_at, type: :string, example: '2018-05-08T21:27:56.929Z'
              property :updated_at, type: :string, example: '2018-05-08T21:27:56.929Z'
              property :guid, type: :string, example: '1e4d33f4-2bf7-44b9-ba2c-121d9a794d87'
              property :encrypted_file_data, type: :string, example: 'WVTedVIfvkqLePMMGNUrrtRvLPXiURrJS8ZuEvQ//Lim'
              property :encrypted_file_data_iv, type: :string, example: 'ayqrfIpruCPtLGnA'
            end
          end
        end
      end
    end
  end
end
