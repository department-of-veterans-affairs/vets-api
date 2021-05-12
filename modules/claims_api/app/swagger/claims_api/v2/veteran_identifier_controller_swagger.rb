# frozen_string_literal: true

module ClaimsApi
  module V2
    class VeteranIdentifierControllerSwagger
      include Swagger::Blocks

      swagger_path '/veteran-identifier' do
        operation :get do
          key :summary, 'Retrieve ICN of Veteran'
          key :description, "Allows authenticated veteran's and veteran representatives to retrieve a veteran's ICN."
          key :operationId, 'getVeteranIdentifier'
          key :tags, ['Veteran Identifier']
          security { key :bearer_token, [] }

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

          response 200 do
            key :description, "Veteran's ID"
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
                      key :description, 'HTTP error code'
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
        end
      end
    end
  end
end
