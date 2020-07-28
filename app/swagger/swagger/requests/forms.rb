# frozen_string_literal: true

module Swagger
  module Requests
    class Forms
      include Swagger::Blocks

      swagger_path '/v0/forms' do
        operation :get do
          key :description, 'Returns a list of forms from the VA Lighthouse API, filtered using an optional search term'
          key :operationId, 'getForms'
          key :tags, %w[
            forms
          ]

          parameter do
            key :name, 'term'
            key :in, :query
            key :description, 'Query the form number as well as title'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'Successful forms query'
            schema do
              key :'$ref', :Forms
            end
          end
        end
      end
    end
  end
end
