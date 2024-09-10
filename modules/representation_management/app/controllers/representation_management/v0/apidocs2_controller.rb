# frozen_string_literal: true

module RepresentationManagement
  module V0
    class Apidocs2Controller < ApplicationController
      service_tag 'representation-management'
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
          key :name, 'representation_management'
          key :description, 'Representation Management'
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
      end

      # A list of all classes that have swagger_* declarations.
      SWAGGERED_CLASSES = [
        RepresentationManagement::V0::PdfGenerator2122Controller,
        self
      ].freeze

      def index
        render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
      end
    end
  end
end
