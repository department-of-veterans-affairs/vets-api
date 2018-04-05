module V0
  module Benefits
    class FormUploadsController < ApplicationController
      include Swagger::Blocks

      swagger_path '/form_uploads' do
        operation :post do
          key :tags, %w[form_uploads]
          key :summary, 'Upload a benefits form'
          key :operationId, 'postBenefitsFormUpload'
          key :consumes, %w[multipart/form-data]

          parameter do
            key :name, :apitoken
            key :description, 'API token provided by Vets.gov.'
            key :required, true
            key :type, :string
            key :in, :query
          end

          parameter do
            key :name, :file
            key :description, 'Form file. Should be provided in PDF format.'
            key :required, true
            key :type, :file
            key :in, :formData
          end

          response 200 do
            key :description, 'Upload received'

            schema do
              property :id, type: :string, description: 'Identifier for subsequent getStatus requests'
            end
          end
        end
      end

      def create

      end

      swagger_path '/form_uploads/{id}' do
        operation :get do
          key :tags, %w[form_uploads]

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
