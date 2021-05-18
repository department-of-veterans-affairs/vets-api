# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsControllerSwagger
        include Swagger::Blocks

        swagger_path '/veterans/{veteran_id}/claims' do
          operation :get do
            key :summary, 'Find all claims for a Veteran.'
            key :description, 'Retrieves all claims for Veteran.'
            key :operationId, 'findClaims'
            key :produces, ['application/json']
            key :tags, ['Claims']

            security do
              key :bearer_token, []
            end

            parameter do
              key :name, 'veteran_id'
              key :in, :path
              key :description, 'ID of Veteran'
              key :required, true
              key :type, :string
            end

            response 200 do
              key :description, 'claim response'
              content 'application/json' do
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
                        key :example, 'Not authorized'
                      end

                      property :detail do
                        key :type, :string
                        key :example, 'Not authorized'
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

            response 404 do
              key :description, 'Resource not found'
              content 'application/json' do
                schema do
                  key :type, :object
                  key :required, [:errors]
                  property :errors do
                    key :type, :array
                    items do
                      property :title do
                        key :type, :string
                        key :example, 'Resource not found'
                      end

                      property :detail do
                        key :type, :string
                        key :example, 'Resource not found'
                        key :description, 'HTTP error detail'
                      end

                      property :code do
                        key :type, :string
                        key :example, '404'
                      end

                      property :status do
                        key :type, :string
                        key :example, '404'
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
end
