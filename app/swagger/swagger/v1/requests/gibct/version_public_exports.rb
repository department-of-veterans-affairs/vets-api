# frozen_string_literal: true

module Swagger
  module V1
    module Requests
      module Gibct
        class VersionPublicExports
          include Swagger::Blocks

          swagger_path '/v1/gi/public_exports/{id}' do
            operation :get do
              key :description, 'Retrieves the latest institution data export file'
              key :operationId, 'gibctVersionPublicExport'
              key :tags, %w[gi_bill_institutions]
              key :produces, ['text/plain']

              parameter description: 'Version ID to fetch export for',
                        in: :path,
                        name: :id,
                        required: true,
                        type: :string

              response 200 do
                key :description, '200 passes the response from the upstream GIDS controller'
                schema do
                  key :type, :file
                end
              end

              response 404 do
                key :description, 'Version ID not found'
                schema '$ref': :Errors
              end
            end
          end
        end
      end
    end
  end
end
