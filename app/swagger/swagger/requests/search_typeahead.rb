# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class SearchTypeahead
      include Swagger::Blocks

      swagger_path '/v0/search_typeahead' do
        operation :get do
          key :description, 'Returns a list of search results, from Search.gov, for the passed search query'
          key :operationId, 'getSearchResults'
          key :tags, %w[
            search
          ]

          parameter do
            key :name, 'query'
            key :in, :query
            key :description, 'The search term being queried'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, [:body]
              property :body, type: :array do
                items do
                  property :suggestion, type: :string
                end
              end
            end
          end

          response 400 do
            key :description, 'Error Occurred'
            schema do
              key :$ref, :Errors
            end
          end

          response 429 do
            key :description, 'Exceeded rate limit'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Exceeded rate limit'
                  property :detail,
                           type: :string,
                           example: 'Exceeded Search.gov rate limit'
                  property :code, type: :string, example: 'SEARCH_429'
                  property :status, type: :string, example: '429'
                  property :source, type: :string, example: 'Search::Service'
                end
              end
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
