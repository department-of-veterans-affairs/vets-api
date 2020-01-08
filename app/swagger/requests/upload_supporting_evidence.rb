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
            key :in, :body
            key :description, 'Object containing file name'
            key :required, true

            schema do
              property :file_data, type: :string, example: 'filename.pdf'
            end
          end

          response 200 do
            key :description, 'Response is ok'
            schema do
              key :'$ref', :UploadSupportingEvidence
            end
          end

          response 400 do
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
