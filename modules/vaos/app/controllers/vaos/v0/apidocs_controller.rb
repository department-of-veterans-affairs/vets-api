# frozen_string_literal: true

module VAOS
  module V0
    class ApidocsController < ApplicationController
      include Swagger::Blocks
      skip_before_action :authenticate

      swagger_root do
        key :swagger, '2.0'
        info do
          key :version, '1.0.0'
          key :title, 'va.gov VAOS Service API'
          key :description, 'The API for managing VA Online Scheduling on va.gov'
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
          key :name, 'authentication'
          key :description, 'Authentication operations'
        end
        tag do
          key :name, 'user'
          key :description, 'Current authenticated user data'
        end
        tag do
          key :name, 'appointments'
          key :description, 'User profile information'
        end
        tag do
          key :name, 'systems'
          key :description, 'Veteran benefits profile information'
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

        parameter :optional_page_number, name: :page, in: :query, required: false, type: :integer,
                                         description: 'Page of results, greater than 0 (default: 1)'

        parameter :optional_page_length, name: :per_page, in: :query, required: false, type: :integer,
                                         description: 'number of results, between 1 and 99 (default: 10)'

        parameter :optional_sort, name: :sort, in: :query, required: false, type: :string,
                                  description: "Comma separated sort field(s), prepend with '-' for descending"

        parameter :optional_filter, name: :filter, in: :query, required: false, type: :string,
                                    description: 'Filter on refill_status: [[refill_status][logical operator]=status]'
      end

      SWAGGERED_CLASSES = [
        VAOS::Requests::Systems,
        VAOS::Schemas::Systems,
        Swagger::Schemas::Errors,
        self
      ].freeze

      def index
        render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
      end
    end
  end
end
