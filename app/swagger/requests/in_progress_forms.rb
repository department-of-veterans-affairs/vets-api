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

          key :summary,     'Get form data'
          key :description, "When a GET request is made for a user completing disability claim form 21-526EZ
            for the first time, the API service will make a call to the Master Veteran Index (MVI) requesting
            that MVI make calls to upstream services to find or create the user's CorpDB (Corp) ID,
            and possibly the user's Beneficiary Identification and Records Locator Subsystem (BIRLS) ID. MVI will
            save the IDs it discovers to its own database. The Corp and BIRLS IDs are required prerequisites
            for serving the 21-526EZ disability claim form to the client."
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
            schema do
              key :'$ref', :FormOutputData
            end
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
            key :description, 'new data for the form'
            key :required, true
            schema do
              key :'$ref', :FormInputData
            end
          end

          response 200 do
            key :description, 'update form response'
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

      swagger_schema :FormInputData, required: [:form_data] do
        property :form_data do
          key :type, :string
        end
      end
    end
  end
end
