# frozen_string_literal: true

module Swagger
  module Requests
    class Banners
      include Swagger::Blocks

      swagger_path '/v0/banners' do
        operation :get do
          key :description, 'Returns banners that match the specified path and banner type'
          key :operationId, 'getBannersByPath'
          key :tags, ['banners']

          parameter do
            key :name, 'path'
            key :in, :query
            key :description, 'Path to match banners against'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'type'
            key :in, :query
            key :description, 'Banner type to filter by (default: "full_width_banner_alert")'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'Banners retrieved successfully'
            schema do
              property :banners do
                key :type, :array
                items do
                  property :id, type: :integer
                  property :entity_bundle, type: :string
                  property :context do
                    key :type, :array
                    items do
                      property :entity do
                        property :entityUrl do
                          property :path, type: :string
                        end
                      end
                    end
                  end
                end
              end
              property :path, type: :string
              property :banner_type, type: :string
            end
          end

          response 422 do
            key :description, 'Unprocessable Entity'
            schema do
              property :error do
                key :type, :string
                key :example, 'Path parameter is required'
              end
            end
          end
        end
      end
    end
  end
end
