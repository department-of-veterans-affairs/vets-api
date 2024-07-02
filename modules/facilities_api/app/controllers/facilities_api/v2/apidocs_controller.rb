# frozen_string_literal: true

module FacilitiesApi
  module V2
    class ApidocsController < ApplicationController
      include Swagger::Blocks
      service_tag 'facility-locator'

      swagger_root do
        key :swagger, '2.0'
        info do
          key :version, '2.0.0'
          key :title, 'va.gov API'
          key :description, 'The API for managing va.gov'
          key :termsOfService, ''
          contact do
            key :name, 'va.gov team'
          end
        end
        # Tags are used to group endpoints in tools like swagger-ui
        # Groups/tags are displayed in the order declared here, followed
        # by the order they first appear in the swaggered_classes below, so
        # declare all tags here in desired order.
        tag do
          key :name, 'facilities'
          key :description, 'VA facilities, locations, hours of operation, available services'
        end

        key :host, Settings.hostname
        key :schemes, %w[https http]
        key :basePath, '/'
        key :consumes, ['application/json']
        key :produces, ['application/json']

        parameter :optional_page_number,
                  name: :page,
                  in: :query,
                  required: false,
                  type: :integer,
                  description: 'Page of results, greater than 0 (default: 1)'

        parameter :optional_page_length,
                  name: :per_page,
                  in: :query,
                  required: false,
                  type: :integer,
                  description: 'number of results, between 1 and 99 (default: 10)'
      end

      SWAGGERED_CLASSES = [
        FacilitiesApi::V2::Requests::Facilities,
        FacilitiesApi::V2::Schemas::Facilities,
        FacilitiesApi::V2::Schemas::Errors,
        self
      ].freeze

      def index
        render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
      end
    end
  end
end
