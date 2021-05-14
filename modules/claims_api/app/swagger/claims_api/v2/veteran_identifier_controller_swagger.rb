# frozen_string_literal: true

module ClaimsApi
  module V2
    class VeteranIdentifierControllerSwagger
      include Swagger::Blocks

      swagger_path '/veteran-id:find' do
        operation :post do
          key :summary, 'Retrieve id of Veteran'
          key :description, "Allows authenticated veterans and veteran representatives to retrieve a veteran's id."
          key :operationId, 'getVeteranIdentifier'
          key :tags, ['Veteran Identifier']
          key :consumes, ['application/json']
          key :produces, ['application/json']
          security { key :bearer_token, [] }

          request_body do
            key :description, 'JSON API Payload of Veteran being submitted'
            key :required, true
            content 'application/json' do
              schema do
                key :type, :object
                key :required, %i[ssn firstName lastName birthdate]
                property :ssn do
                  key :type, :string
                  key :example, '796130115'
                  key :description, 'SSN of Veteran being represented'
                end
                property :firstName do
                  key :type, :string
                  key :example, 'Tamara'
                  key :description, 'First Name of Veteran being represented'
                end
                property :lastName do
                  key :type, :string
                  key :example, 'Ellis'
                  key :description, 'Last Name of Veteran being represented'
                end
                property :birthdate do
                  key :type, :string
                  key :example, '1967-06-19'
                  key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
                end
              end
            end
          end

          response 200 do
            key :description, "Veteran's unique identifier"
            content 'application/json' do
              schema do
                key :type, :object
                property :id do
                  key :type, :string
                  key :example, '1012667145V762142'
                end
              end
            end
          end

          response 400 do
            key :description, 'Bad Request'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    property :title do
                      key :type, :string
                      key :example, 'Missing parameter'
                      key :description, 'Error Title'
                    end

                    property :detail do
                      key :type, :string
                      key :example, 'The required parameter X, is missing'
                      key :description, 'HTTP error detail'
                    end

                    property :code do
                      key :type, :string
                      key :example, '108'
                    end

                    property :status do
                      key :type, :string
                      key :example, '400'
                      key :description, 'HTTP error code'
                    end
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
                    property :title do
                      key :type, :string
                      key :example, 'Unauthorized'
                    end

                    property :detail do
                      key :type, :string
                      key :example, 'Unauthorized'
                      key :description, 'HTTP error detail'
                    end

                    property :code do
                      key :type, :string
                      key :example, '401'
                    end

                    property :status do
                      key :type, :string
                      key :example, '401'
                      key :description, 'HTTP error code'
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
end
