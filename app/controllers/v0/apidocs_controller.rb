# frozen_string_literal: true
module V0
  class ApidocsController < ApplicationController::Base
    include Swagger::Blocks

    swagger_root do
      key :swagger, '2.0'
      info do
        key :version, '1.0.0'
        key :title, 'vets.gov API'
        key :description, 'The API for managing vets.gov'
        key :termsOfService, ''
        contact do
          key :name, 'vets.gov team'
        end
        license do
          key :name, 'Creative Commons Zero v1.0 Universal'
        end
      end
      tag do
        key :name, 'sessions'
        key :description, 'Authentication operations'
      end
      tag do
        key :name, 'in_progress_forms'
        key :description, 'In-progress form operations'
      end

      key :host, 'vets.gov'
      key :basePath, '/'
      key :consumes, ['application/json']
      key :produces, ['application/json']

      parameter :authorization do
        key :name, 'Authorization'
        key :in, :header
        key :description, 'The authorization method and token value'
        key :required, true
        key :type, :string
      end
    end

    # A list of all classes that have swagger_* declarations.
    SWAGGERED_CLASSES = [
      Swagger::Requests::InProgressForms,
      Swagger::Requests::Sessions,
      Swagger::Requests::User,
      Swagger::Responses::AuthenticationError,
      Swagger::Schemas::Errors,
      self
    ].freeze

    def index
      render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
    end
  end
end
