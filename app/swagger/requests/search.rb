# frozen_string_literal: true

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
            key :description, 'The search term being queried'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, [:data]
              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  key :required, [:body]
                  property :body, type: :object do
                    property :query, type: :string
                    property :web, type: :object do
                      property :total, type: :integer
                      property :next_offset, type: :integer
                      property :spelling_correction, type: %i[string null]
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
                      items do
                        property :id, type: :integer
                        property :title, type: :string, description: 'Title of the best bet'
                        property :url, type: :string
                        property :description, type: :string
                      end
                    end
                    property :graphic_best_bets do
                      key :type, :array
                      items do
                        property :title, type: :string
                        property :title_url, type: :string
                        property :image_url, type: :string
                        property :image_alt_text, type: :string
                        property :links do
                          key :type, :array
                          items do
                            key :type, :string
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
                          items do
                            key :type, :string
                          end
                        end
                        property :related_sites do
                          key :type, :array
                          items do
                            key :type, :string
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
                        property :minimum, type: :string
                        property :maximum, type: :string
                        property :start_date, type: :string
                        property :end_date, type: :string
                        property :url, type: :string
                        property :locations do
                          key :type, :array
                          items do
                            key :type, :string
                          end
                        end
                        property :related_sites do
                          key :type, :array
                          items do
                            key :type, :string
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
                        property :screen_name, type: :string
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
                        property :agency_names, type: :string
                        property :page_length, type: :string
                        property :start_page, type: :string
                        property :end_page, type: :string
                        property :publication_date, type: :string
                        property :comments_close_date, type: :string
                      end
                    end
                    property :related_search_terms do
                      key :type, :array
                      items do
                        key :type, :string
                      end
                    end
                  end
                end
              end
            end
          end

          response 400 do
            key :description, 'Error Occurred'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
