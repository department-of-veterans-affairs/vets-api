# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class Search
      include Swagger::Blocks

      swagger_path '/v0/search' do
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
                  key :required, [:body]
                  property :body, type: :object do
                    property :query, type: :string, description: 'The term used to generate these search results'
                    property :web, type: :object do
                      property :total, type: :integer, description: 'Total number of results available.'
                      property :next_offset, type: :integer, description: 'Offset for the subsequent results.'
                      property :spelling_correction,
                               type: %i[string null],
                               description: 'Spelling correction for your search term.'
                      property :results do
                        key :type, :array
                        items do
                          property :title, type: :string
                          property :url, type: :string
                          property :snippet, type: :string
                          property :publication_date, type: %i[string null]
                        end
                      end
                    end
                    property :text_best_bets do
                      key :type, :array
                      key :description, 'Text best bets, which appear only when the query matches the text of the best bet’s title, description, or keywords.'
                      items do
                        property :id, type: :integer
                        property :title, type: :string
                        property :url, type: :string
                        property :description, type: :string
                      end
                    end
                    property :graphic_best_bets do
                      key :type, :array
                      key :description, 'Graphic best bets, which appear only when the query matches the text of the best bet’s title, description, or keywords.'
                      items do
                        property :id, type: :integer
                        property :title, type: :string
                        property :title_url, type: :string
                        property :image_url, type: :string
                        property :image_alt_text, type: :string
                        property :links do
                          key :type, :array
                          key :description, 'An array of links in the graphic best bet. Each link contains a title and a URL'
                          items do
                            property :title, type: :string
                            property :url, type: :string
                          end
                        end
                      end
                    end
                    property :health_topics do
                      key :type, :array
                      items do
                        property :title, type: :string
                        property :url, type: :string
                        property :snippet, type: :string
                        property :related_topics do
                          key :type, :array
                          key :description, 'An array of topics related to the health topic. Each topic contains a title and a URL'
                          items do
                            property :title, type: :string
                            property :url, type: :string
                          end
                        end
                        property :related_sites do
                          key :type, :array
                          key :description, 'An array of sites related to the the health topic. Each site contains a title and a URL'
                          items do
                            property :title, type: :string
                            property :url, type: :string
                          end
                        end
                      end
                    end
                    property :job_openings do
                      key :type, :array
                      items do
                        property :position_title, type: :string
                        property :organization_name, type: :string
                        property :rate_interval_code, type: :string
                        property :minimum, type: :integer, description: 'Minimum salary of the job opening'
                        property :maximum, type: :integer, description: 'Maximum salary of the job opening'
                        property :start_date, type: :string
                        property :end_date, type: :string
                        property :url, type: :string
                        property :org_codes, type: :string
                        property :locations do
                          key :type, :array
                          key :description, 'An array of locations of the job opening'
                          items do
                            key :type, :string
                          end
                        end
                        property :related_sites do
                          key :type, :array
                          items do
                            property :title, type: :string
                            property :url, type: :string
                          end
                        end
                      end
                    end
                    property :recent_tweets do
                      key :type, :array
                      items do
                        property :text, type: :string
                        property :url, type: :string
                        property :name, type: :string
                        property :snippet, type: :string
                        property :screen_name, type: :string, description: 'Screen name of the tweet author'
                        property :profile_image_url, type: :string
                      end
                    end
                    property :recent_news do
                      key :type, :array
                      items do
                        property :title, type: :string
                        property :url, type: :string
                        property :snippet, type: :string
                        property :publication_date, type: :string
                        property :source, type: :string
                      end
                    end
                    property :recent_video_news do
                      key :type, :array
                      items do
                        property :title, type: :string
                        property :url, type: :string
                        property :snippet, type: :string
                        property :publication_date, type: :string
                        property :source, type: :string
                        property :thumbnail_url, type: :string
                      end
                    end
                    property :federal_register_documents do
                      key :type, :array
                      items do
                        property :id, type: :integer
                        property :document_number, type: :string
                        property :document_type, type: :string
                        property :title, type: :string
                        property :url, type: :string
                        property :agency_names do
                          key :type, :array
                          key :description, 'An array of agency names of the federal register document'
                          items do
                            key :type, :string
                          end
                        end
                        property :page_length, type: :integer
                        property :start_page, type: :integer
                        property :end_page, type: :integer
                        property :publication_date, type: :string
                        property :comments_close_date, type: :string
                      end
                    end
                    property :related_search_terms do
                      key :type, :array
                      key :description, 'An array of related search terms, which are based on recent, common searches on the your site.'
                      items do
                        key :type, :string
                      end
                    end
                  end
                end
              end

              property :meta do
                property :pagination, '$ref': :Pagination
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
