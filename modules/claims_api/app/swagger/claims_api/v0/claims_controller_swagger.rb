# frozen_string_literal: true

module ClaimsApi
  module V0
    class ClaimsControllerSwagger
      include Swagger::Blocks

      swagger_path '/claims/{id}' do
        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Find Claim by ID'
          key(
            :description,
            <<~X
              Returns data such as processing status for a single claim by ID.
            X
          )
          key :operationId, 'findClaimById'
          key :tags, [
            'Claims'
          ]

          parameter do
            key :name, 'apikey'
            key :in, :header
            key :description, 'API Key given to access data'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'The ID of the claim being requested'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :example, '123121234'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :example, 'John'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :example, 'Doe'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :example, '1954-12-15'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-User'
            key :in, :header
            key :description, 'VA username of the person making the request'
            key :example, 'lighthouse'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-LOA'
            key :in, :header
            key :description, 'The level of assurance of the user making the request'
            key :example, '3'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'claims response'
            schema do
              key :type, :object
              key :required, [:data]
              property :data do
                key :$ref, :ClaimsShow
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
        end
      end

      swagger_path '/claims' do
        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Find all claims for a Veteran.'
          key(
            :description,
            <<~X
              Uses the Veteran’s metadata in headers to retrieve all claims for that Veteran. An authenticated Veteran making a request with this endpoint will return their own claims, if any.
            X
          )
          key :operationId, 'findClaims'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Claims'
          ]

          parameter do
            key :name, 'apikey'
            key :in, :header
            key :description, 'API Key given to access data'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :example, '123121234'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :example, 'John'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :example, 'Doe'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :example, '1954-12-15'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-User'
            key :in, :header
            key :description, 'VA username of the person making the request'
            key :example, 'lighthouse'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-LOA'
            key :in, :header
            key :description, 'The level of assurance of the user making the request'
            key :example, '3'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'claim response'
            schema do
              key :type, :object
              key :required, [:data]
              property :data do
                key :type, :array
                items do
                  key :$ref, :ClaimsIndex
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
        end
      end
    end
  end
end
