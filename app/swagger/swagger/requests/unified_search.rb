# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class UnifiedSearch
      include Swagger::Blocks

      swagger_path '/v0/unified_search' do
        operation :get do
          key :description, 'Returns a list of search results, from AWS Kendra index, for the passed search query'
          key :operationId, 'getUnifiedSearchResults'
          key :tags, %w[search]

          parameter do
            key :name, 'query'
            key :in, :query
            key :description, 'The search term being queried'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'page'
            key :in, :query
            key :description, 'The page number for the page of results that is being requested'
            key :required, false
            key :type, :integer
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, %i[data meta]
              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  key :required, %i[query results total]
                  property :query, type: :string, description: 'Echo of the user query'
                  property :source, type: %i[string null], description: 'Applied source filter, if any'
                  property :page, type: :integer, description: 'Current page number'
                  property :per_page, type: :integer, description: 'Page size'
                  property :total, type: :integer, description: 'Total number of matching results'
                  property :spelling_correction, type: %i[string null], description: 'Suggested corrected query, if applicable'

                  property :results do
                    key :type, :array
                    items do
                      property :id, type: :string, description: 'Stable document ID (usually canonical URL)'
                      property :title, type: :string
                      property :url, type: :string
                      property :snippet, type: :string
                      property :source, type: :string, description: 'sitewide | resources_support | forms'
                      property :mime_type, type: %i[string null], description: 'e.g., text/html, application/pdf'
                      property :content_type, type: %i[string null], description: 'Logical type (article, form, page, faq, pdf)'
                      property :publication_date, type: %i[string null], description: 'ISO8601'
                      property :updated_date, type: %i[string null], description: 'ISO8601'
                      property :score, type: %i[number null], format: :float, description: 'Relevance score from Kendra'
                    end
                  end
                end
              end

              property :meta, type: :object do
                property :pagination, '$ref': :Pagination
              end
            end
          end

          response 400 do
            key :description, 'Error Occured'
            schema do
              key :$ref, :Errors
            end
          end

          response 429 do
            key :description, 'Rate limit exeeded'
            schema do
              key :required, [:errors]
              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Exceeded rate limit'
                  property :detail, type: :string, example: 'Exceeded unified search rate limit'
                  property :code, type: :string, example: 'SEARCH_429'
                  property :status, type: :string, example: '429'
                  property :source, type: :string, example: 'Search::UnifiedService'
                end
              end
            end
          end

          response 502 do
            key :description, 'Upstream (Kendra) error'
            schema do
              key :$ref, :Errors
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
