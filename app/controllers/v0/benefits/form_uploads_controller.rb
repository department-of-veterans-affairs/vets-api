module V0
  module Benefits
    class FormUploadsController < ApplicationController
      include Swagger::Blocks

      swagger_path '/' do
        operation :post do
          key :summary, 'Upload a benefits form'
          key :operationId, 'postBenefitsFormUpload'

          response 200 do
            key :description, 'Upload received'

            schema do
              property :uuid, type: :string # TODO: is there a uuid type?
            end
          end
        end
      end

      swagger_path '/{id}' do
        operation :get do
          key :summary, 'Get status for existing benefits form upload'
          key :operationId, 'getBenefitsFormUploadStatus'

          response 200 do
            key :description, 'Upload status retrieved successfully'
            schema do
              property :hello, type: :string
            end
          end
        end
      end
    end
  end
end
