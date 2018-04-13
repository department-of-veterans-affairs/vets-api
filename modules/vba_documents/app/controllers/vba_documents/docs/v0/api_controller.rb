# frozen_string_literal: true

module VBADocuments
  module Docs
    module V0
      class ApiController < ApplicationController
        include Swagger::Blocks

        skip_before_action :authenticate

        swagger_root do
          key :swagger, '2.0'
          info do
            key :version, '0.0.0'
            key :title, 'Benefits'
            key :description, 'Veterans Benefits Administration (VBA) document uploads.'
            key :termsOfService, ''
            contact do
              key :name, 'Vets.gov'
            end
          end

          security_definition :api_key do
            key :type, :apiKey
            key :name, :apikey
            key :in, :query
          end

          tag do
            key :name, 'document_uploads'
            key :description, 'VA Benefits document upload functionality'
          end

          key :host, Settings.hostname
          key :basePath, '/v0/benefits'
          key :consumes, ['application/json']
          key :produces, ['application/json']
        end

        # A list of all classes that have swagger_* declarations.
        SWAGGERED_CLASSES = [
          VBADocuments::V0::UploadsController,
          self
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
