# frozen_string_literal: true

module V1
  class ApidocsController < ApplicationController
    include Swagger::Blocks

    skip_before_action :authenticate

    swagger_root do
      key :swagger, '2.0'
      info do
        key :version, '1.0.0'
        key :title, 'va.gov API'
        key :description, 'The API for managing va.gov'
        key :termsOfService, ''
        contact do
          key :name, 'va.gov team'
        end
        license do
          key :name, 'Creative Commons Zero v1.0 Universal'
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
      tag do
        key :name, 'higher_level_reviews'
        key :description, 'Request a senior reviewer take a new look at a case'
      end
      tag do
        key :name, 'income_limits'
        key :description, 'Get income limit thresholds for veteran benefits.'
      end
      key :host, Settings.hostname
      key :schemes, %w[https http]
      key :basePath, '/'
      key :consumes, ['application/json']
      key :produces, ['application/json']

      [true, false].each do |required|
        parameter :"#{required ? '' : 'optional_'}authorization" do
          key :name, 'Authorization'
          key :in, :header
          key :description, 'The authorization method and token value'
          key :required, required
          key :type, :string
        end
      end

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

    # A list of all classes that have swagger_* declarations.
    SWAGGERED_CLASSES = [
      Swagger::V1::Requests::Facilities,
      Swagger::V1::Schemas::Facilities,
      Swagger::V1::Requests::IncomeLimits,
      Swagger::V1::Schemas::IncomeLimits,
      Swagger::V1::Schemas::Errors,
      Swagger::V1::Requests::Appeals::Appeals,
      Swagger::V1::Schemas::Appeals::Requests,
      Swagger::V1::Schemas::Appeals::HigherLevelReview,
      Swagger::V1::Schemas::Appeals::NoticeOfDisagreement,
      Swagger::V1::Schemas::Appeals::SupplementalClaims,
      self
    ].freeze

    def index
      render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
    end
  end
end
