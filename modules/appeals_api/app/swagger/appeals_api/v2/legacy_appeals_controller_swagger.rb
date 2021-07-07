# frozen_string_literal: true

module AppealsApi
  module V2
    class LegacyAppealsControllerSwagger

      include Swagger::Blocks

      swagger_path '/legacy_appeals' do
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
                key :type, :object

                property :data do
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

          security do
            key :apikey, []
          end
        end
      end
    end
  end
end
