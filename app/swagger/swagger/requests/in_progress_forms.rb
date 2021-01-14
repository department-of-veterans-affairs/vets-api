# frozen_string_literal: true

module Swagger
  module Requests
    class InProgressForms
      include Swagger::Blocks

      swagger_path '/v0/in_progress_forms' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get Saved Form Summaries'
          key :operationId, 'listInProgressForms'
          key :tags, %w[
            in_progress_forms
          ]

          parameter :authorization

          response 200 do
            key :description, 'get saved form summaries'
            schema do
              key :'$ref', :SavedFormSummaries
            end
          end
        end
      end

      swagger_path '/v0/in_progress_forms/{id}' do
        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Delete form data'
          key :operationId, 'deleteInProgressForm'
          key :tags, [
            'in_progress_forms'
          ]
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
            schema do
              key :'$ref', :References
            end
          end
        end

        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get form data'
          key :operationId, 'getInProgressForm'
          key :tags, [
            'in_progress_forms'
          ]

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

        operation :put do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::InternalServerError

          key :description, 'Update form data'
          key :operationId, 'updateInProgressForm'
          key :tags, [
            'in_progress_forms'
          ]

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'ID of the form'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :form_data
            key :in, :body
            key :description, 'new data for the form (alias "formData")'
            key :type, :object
          end

          parameter do
            key :name, :formData
            key :in, :body
            key :description, 'new data for the form (alias "form_data")'
            key :type, :object
          end

          parameter do
            key :name, :metadata
            key :in, :body
            key :description, 'metadata for the form'
            key :type, :object
          end

          response 200 do
            key :description, 'updated form'
            schema { key :'$ref', :InProgressFormShowResponse }
          end
        end
      end

      swagger_schema :References do
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string
        end
      end

      swagger_schema :SavedFormSummaries do
      end

      swagger_schema :FormOutputData do
      end

      swagger_schema :InProgressFormShowResponse do
        property :formData, type: :object
        property :metadata, type: :object
      end

      swagger_schema :InProgressFormUpdateResponse do
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            property :formId, type: :string
            property :createdAt, type: :string
            property :updatedAt, type: :string
            property :vet360_contact_information, type: %i[object null]
          end
        end
      end
    end
  end
end
