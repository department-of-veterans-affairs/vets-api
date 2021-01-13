# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class SearchClickTracking
      include Swagger::Blocks

      swagger_path '/v0/search_click_tracking' do
        operation :post do
          key :description, 'Sends a Click Tracking event to Search.gov analytics'
          key :operationId, 'sendClickTrackingData'
          key :tags, %w[
            search_click_tracking
          ]

          parameter do
            key :name, 'url'
            key :in, :query
            key :description, 'the url of the link that was clicked'
            key :required, true
            key :type, :string
          end
          
          parameter do
            key :name, 'query'
            key :in, :query
            key :description, 'the search query used to generate results'
            key :required, true
            key :type, :string
          end
          
          parameter do
            key :name, 'position'
            key :in, :query
            key :description, 'The position/rank of the result on your search results page. Was it the first result or the second?'
            key :required, true
            key :type, :integer
          end
          
          parameter do
            key :name, 'client_ip'
            key :in, :query
            key :description, 'the IP address of the user who clicked'
            key :required, true
            key :type, :string
          end
          
          parameter do
            key :name, 'user_agent'
            key :in, :query
            key :description, 'the user agent of the user who clicked'
            key :required, true
            key :type, :string
          end


          response 200 do
            key :description, 'Response is OK'
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
# rubocop:enable Layout/LineLength
