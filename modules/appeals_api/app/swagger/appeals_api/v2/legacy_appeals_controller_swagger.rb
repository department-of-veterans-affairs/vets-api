# frozen_string_literal: true

module AppealsApi
  module V2
    class LegacyAppealsControllerSwagger
      include Swagger::Blocks

      PATH_ENABLED_FOR_ENV = Settings.modules_appeals_api.documentation.path_enabled_flag

      ERROR_500_EXAMPLE = {
        errors: [
          {
            title: 'Internal Server Error',
            code: 'internal_server_error',
            detail: 'An unknown error has occurred.',
            status: 500
          }
        ],
        status: 500
      }.freeze

      ERROR_502_EXAMPLE = {
        errors: [
          {
            title: 'Bad Gateway',
            code: 'bad_gateway',
            detail: 'Received an unusable response from Caseflow.',
            status: 502
          }
        ],
        status: 502
      }.freeze

      ERROR_422_EXAMPLE = {
        errors: [
          {
            title: 'Unprocessable Entity',
            code: 'unprocessable_entity',
            detail: 'X-VA-SSN or X-VA-File-Number is required',
            status: 422
          }
        ],
        status: 422
      }.freeze

      swagger_path '/legacy_appeals' do
        next unless PATH_ENABLED_FOR_ENV

        operation :get, tags: ['Legacy Appeals'] do
          key :operationId, 'getLegacyAppeals'
          key :summary, 'returns a list of Legacy Appeals scoped to the Veteran'
          key :description, 'Returns all of the data associated with a Veteran\'s Legacy Appeals'

          parameter name: 'X-VA-SSN', in: 'header', description: 'veteran\'s ssn' do
            key :description, 'Either X-VA-SSN or X-VA-File-Number is required'
            schema '$ref': 'X-VA-SSN'
          end

          parameter name: 'X-VA-File-Number', in: 'header', description: 'veteran\'s file number' do
            key :description, 'Either X-VA-SSN or X-VA-File-Number is required'
            schema type: :string
          end

          response 200 do
            key :description, 'Returns all of the data associated with a Veteran\'s Legacy Appeals'

            content 'application/json' do
              schema do
                property :data do
                  key :type, :array

                  items do
                    property :id do
                      key :'$ref', :uuid
                    end

                    property :type do
                      key :type, :string
                      key :example, 'LegacyAppeal'
                    end

                    property :attributes do
                      key :$ref, '#/components/schemas/legacyAppeal'
                    end
                  end
                end
              end
            end
          end

          response 500 do
            key :description, 'Internal Error response'
            content 'application/json' do
              schema do
                key :type, :object
                key :example, ERROR_500_EXAMPLE
                property :errors do
                  key :type, :array

                  items do
                    key :$ref, :errorModel
                  end
                end
              end
            end
          end

          response 502 do
            key :description, 'Internal Error response'
            content 'application/json' do
              schema do
                key :type, :object
                key :example, ERROR_502_EXAMPLE
                property :errors do
                  key :type, :array

                  items do
                    key :$ref, :errorModel
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Internal Error response'
            content 'application/json' do
              schema do
                key :type, :object
                key :example, ERROR_422_EXAMPLE
                property :errors do
                  key :type, :array

                  items do
                    key :$ref, :errorModel
                  end
                end
              end
            end
          end

          security do
            key :apikey, []
          end
        end
      end
    end
  end
end
