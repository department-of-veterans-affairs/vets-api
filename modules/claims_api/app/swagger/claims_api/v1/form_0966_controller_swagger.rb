# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  module V1
    class Form0966ControllerSwagger
      include Swagger::Blocks
      EXAMPLE_PATH = ClaimsApi::Engine.root.join('app', 'swagger', 'claims_api', 'forms', 'form_0966_v1_example.json')

      swagger_path '/forms/0966' do
        operation :get do
          key :deprecated, true
          key :summary, 'Get a 0966 schema for a form.'
          key :description, 'Returns 0966 schema to automatically generate a form.'
          key :operationId, 'get0966JsonSchema'
          key :summary, 'Get 0966 JSON Schema for form'
          key :description, 'Returns a single 0966 JSON schema to auto generate a form'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Intent to File'
          ]
          security do
            key :bearer_token, []
          end

          response 200 do
            key :description, 'schema response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :type, :array
                  items do
                    key :type, :object
                    key :description, 'Returning Variety of JSON and UI Schema Objects'
                    key :example, ClaimsApi::FormSchemas.new.schemas['0966']
                  end
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :NotAuthorizedModel
                  end
                end
              end
            end
          end
        end

        operation :post do
          key :summary, 'Submit form 0966 Intent to File.'
          key :description, 'Establishes an intent to file for disability compensation, burial, or pension claims.'
          key :operationId, 'post0966itf'
          key :tags, [
            'Intent to File'
          ]

          security do
            key :bearer_token, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          request_body do
            key :description, 'JSON API Payload of Veteran being submitted'
            key :required, true
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :type, :object
                  key :required, [:attributes]
                  key :example, JSON.parse(File.read(EXAMPLE_PATH))
                  property :attributes do
                    key :required, %i[type]
                    key :type, :object
                    property :type do
                      key :type, :string
                      key :example, 'compensation'
                      key :description, 'For type "burial", the request must be made by a valid Veteran Representative.
                      If the Representative is not a Veteran or a VA employee, this method is currently not available to them,
                      and they should use the Benefits Intake API as an alternative.'
                      key :enum, %w[
                        compensation
                        burial
                        pension
                      ]
                    end
                    property :participant_claimant_id do
                      key :type, :integer
                      key :example, 123_456_789
                      key :description, I18n.t('claims_api.field_descriptions.participant_claimant_id')
                    end
                  end
                end
              end
            end
          end

          response 200 do
            key :description, '0966 response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :$ref, :Form0966Output
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :NotAuthorizedModel
                  end
                end
              end
            end
          end

          response 403 do
            key :description, 'Forbidden'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :ForbiddenModel
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Unprocessable entity'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/0966/active' do
        operation :get do
          key :summary, 'Returns last active 0966 Intent to File form submission.'
          key :description, 'Returns the last active 0966 form for a Veteran.'
          key :operationId, 'active0966itf'
          key :tags, [
            'Intent to File'
          ]
          security do
            key :bearer_token, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'type'
            key :in, :query
            key :description, 'The type of 0966 you wish to get the active submission for'
            key :required, true
            key :example, 'compensation'
          end

          response 200 do
            key :description, '0966 response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :$ref, :Form0966Output
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :NotAuthorizedModel
                  end
                end
              end
            end
          end

          response 404 do
            key :description, 'Resource not found'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :NotFoundModel
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Unprocessable entity'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/0966/validate' do
        operation :post do
          key :deprecated, true
          key :summary, 'Test the 0966 Intent to File form submission.'
          key :description, 'Test to ensure the form submission works with your parameters. Submission is validated against the GET /forms/0966 schema.'
          key :operationId, 'validate0966itf'
          key :tags, [
            'Intent to File'
          ]

          security do
            key :bearer_token, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          request_body do
            key :description, 'JSON API Payload of Veteran being submitted'
            key :required, true
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :type, :object
                  key :required, [:attributes]
                  key :example, type: 'form/0966', attributes: { type: 'compensation' }
                  property :attributes do
                    key :type, :object
                    property :type do
                      key :type, :string
                      key :example, 'compensation'
                      key :description, 'For type "burial", the request must be made by a valid Veteran Representative.
                      If the Representative is not a Veteran or a VA employee, this method is currently not available to them,
                      and they should use the Benefits Intake API as an alternative.'
                      key :enum, %w[
                        compensation
                        burial
                        pension
                      ]
                    end
                  end
                end
              end
            end
          end

          response 200 do
            key :description, 'Valid'
            content 'application/json' do
              key(
                :examples,
                {
                  default: {
                    value: {
                      data: { type: 'intentToFileValidation', attributes: { status: 'valid' } }
                    }
                  }
                }
              )
              schema do
                key :type, :object
                property :data do
                  key :type, :object
                  property :type, type: :string
                  property :attributes do
                    key :type, :object
                    property :status, type: :string
                  end
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :NotAuthorizedModel
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Unprocessable entity'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
