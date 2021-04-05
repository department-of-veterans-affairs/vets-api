# frozen_string_literal: true

module Swagger
  module Requests
    class SearchTypeahead
      include Swagger::Blocks

      swagger_path '/v0/search_typeahead' do
        operation :get do
          key :description, 'Returns a list of search query suggestions, from Search.gov, for the passed search query'
          key :operationId, 'getSearchTypeaheadSuggestions'
          key :tags, %w[
            search_typeahead
          ]

          parameter do
            key :name, 'query'
            key :in, :query
            key :description, 'The search term being queried'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Debt letter download'

            schema do
              property :data, type: :string
            end
          end
        end
      end
    end
  end
end
