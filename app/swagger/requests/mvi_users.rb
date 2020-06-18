# frozen_string_literal: true

module Swagger
  module Requests
    class MviUsers
      include Swagger::Blocks

      swagger_path '/v0/mvi_users/{id}' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ForbiddenError
          extend Swagger::Responses::UnprocessableEntityError

          key :summary, 'Add user to MVI'
          key :description, "Make Orchestrated Search call to the Master Veteran Index (MVI)
            requesting that MVI make calls to upstream services to find or create the user's
            CorpDB (Corp) ID, and possibly the user's Beneficiary Identification and Records
            Locator Subsystem (BIRLS) ID. MVI will save the IDs it discovers to its own database.
            The Corp and BIRLS IDs are required prerequisites for serving the 21-0966 Intent to File
            form and 21-526EZ disability claim form to the client."
          key :operationId, 'postMviUser'
          key :tags, %w[form_526]

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, "ID of the form. Allowed values: '21-0966' (Intent to File),
              '21-526EZ' (Disability Compensation)"
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'MVI Orchestrated Search returned a Success response'
            schema do
              property :message, type: :string, example: 'Success'
            end
          end
        end
      end
    end
  end
end
