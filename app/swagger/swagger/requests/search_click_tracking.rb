# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class SearchClickTracking
      include Swagger::Blocks

      swagger_path '/v0/search_click_tracking/?position={position}&query={query}&url={url}&module_code={module_code}&user_agent={user_agent}' do
        operation :post do
          key :description, 'Sends a Click Tracking event to Search.gov analytics'
          key :operationId, 'sendClickTrackingData'
          key :tags, %w[
            search_click_tracking
          ]

          parameter do
            key :name, 'url'
            key :in, :path
            key :description, 'the url of the link that was clicked'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'query'
            key :in, :path
            key :description, 'the search query used to generate results'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'position'
            key :in, :path
            key :description, 'The position/rank of the result on your search results page. Was it the first result or the second?'
            key :required, true
            key :type, :integer
          end

          parameter do
            key :name, 'user_agent'
            key :in, :path
            key :description, 'the user agent of the user who clicked'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'module_code'
            key :in, :path
            key :description, 'I14Y for web urls, BOOS for best bets, defaults to I14Y'
            key :required, true
            key :type, :string
          end

          response 204 do
            key :description, 'Empty Response'
          end

          response 400 do
            key :description, 'Error Occurred'
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
