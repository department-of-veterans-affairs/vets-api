# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  module V1
    class Form0966ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms/0966' do
        operation :get do
          key :summary, 'Get 0966 JSON Schema for form'
          key :description, 'Returns a single JSON schema to auto generate a form'
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

          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :ErrorModel
                  end
                end
              end
            end
          end
        end

        operation :post do
          key :summary, 'Accepts 0966 Intent to File form submission'
          key :description, 'Accepts JSON payload. Full URL, including query parameters.'
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
            key :description, 'SSN of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran to fetch in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-EDIPI'
            key :in, :header
            key :description, 'EDIPI Number of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-User'
            key :in, :header
            key :description, 'VA username of the person making the request'
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
                      key :description, 'Required by JSON API standard'
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
            key :description, '0966 response'
            content 'application/json' do
              schema do
                key :'$ref', :Form0966Output
              end
            end
          end
          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :ErrorModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/0966/active' do
        operation :get do
          key :summary, 'Returns last active 0966 Intent to File form submission'
          key :description, 'Returns last active JSON payload. Full URL, including query parameters.'
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
            key :description, 'SSN of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran to fetch in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-EDIPI'
            key :in, :header
            key :description, 'EDIPI Number of Veteran to fetch'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-User'
            key :in, :header
            key :description, 'VA username of the person making the request'
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
                key :'$ref', :Form0966Output
              end
            end
          end
          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :ErrorModel
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
