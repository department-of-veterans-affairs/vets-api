# frozen_string_literal: true

module Swagger
  module Requests
    class UploadSupportingEvidence
      include Swagger::Blocks

      swagger_path '/v0/upload_supporting_evidence' do
        operation :post do
          key :description, 'Upload a pdf or image file containing supporting evidence for form 526'
          key :operationId, 'uploadSupportingEvidence'
          key :tags, %w[form_526]

          parameter do
            key :name, :supporting_evidence_attachment
            key :description, 'Object containing file name'
            key :required, true

            schema do
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

          response 500 do
            key :description, 'Bad Gateway: incorrect parameters'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
