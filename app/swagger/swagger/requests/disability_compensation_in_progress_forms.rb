# frozen_string_literal: true

module Swagger
  module Requests
    class DisabilityCompensationInProgressForms
      include Swagger::Blocks

      tags = { tags: %w[in_progress_forms form_526] }

      swagger_path '/v0/disability_compensation_in_progress_forms/{id}' do
        operation :delete, **tags do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Delete form data'
          key :operationId, 'deleteInProgressForm'

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'ID of the form'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'delete form response'
            schema { key :'$ref', :InProgressFormResponse }
          end
        end

        operation :get, **tags do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get form data'
          key :operationId, 'getInProgressForm'

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'ID of the form'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'get form response'
            schema { key :'$ref', :InProgressFormShowResponse }
          end
        end

        operation :put, **tags do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::InternalServerError

          key :description, 'Update form data and metadata'
          key :operationId, 'updateInProgressForm'

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'ID of the form'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :payload
            key :in, :body
            key :description, 'updated form data and metadata. one of "form_data" or "formData" must be present'
            key :required, true
            schema example: { formData: { lastName: 'Smith' }, metadata: { ver: 1 } } do
              property :formData, type: :object, description: '(alias "form_data")'
              property :form_data, type: :object, description: '(alias "formData")'
              property :metadata, type: :object
            end
          end

          response 200 do
            key :description, 'update form response'
            schema { key :'$ref', :InProgressFormResponse }
          end
        end
      end
    end
  end
end
