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
            schema { key :'$ref', :InProgressFormsResponse }
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
            schema { key :'$ref', :InProgressFormResponse }
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

          key :description, 'Update form data and metadata'
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
            key :name, :payload
            key :in, :body
            key :description, 'updated form data and metadata. one of "form_data" or "formData" must be present'
            key :required, true
            schema do
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

      swagger_schema :InProgressFormShowResponse do
        property :formData, type: :object
        property :metadata, type: :object
      end

      swagger_schema :InProgressFormResponse do
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            property :formId, type: :string
            property :createdAt, type: :string
            property :updatedAt, type: :string
            property :metadata, type: :object
          end
        end
      end

      swagger_schema :InProgressFormsResponse do
        property :data, type: :array do
          items type: :object do
            property :id, type: :string
            property :type, type: :string
            property :attributes, type: :object do
              property :formId, type: :string
              property :createdAt, type: :string
              property :updatedAt, type: :string
              property :metadata, type: :object
            end
          end
        end
      end
    end
  end
end
