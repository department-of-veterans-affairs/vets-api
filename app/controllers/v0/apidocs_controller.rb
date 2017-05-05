# frozen_string_literal: true
module V0
  class ApidocsController < ApplicationController
    include Swagger::Blocks

    skip_before_action :authenticate

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

    # A list of all classes that have swagger_* declarations.
    SWAGGERED_CLASSES = [
      Swagger::Requests::InProgressForms,
      Swagger::Requests::Sessions,
      Swagger::Requests::User,
      Swagger::Requests::EducationBenefitsClaims,
      Swagger::Requests::HealthCareApplications,
      Swagger::Requests::Messages::TriageTeams,
      Swagger::Requests::Messages::Folders,
      Swagger::Responses::AuthenticationError,
      Swagger::Schemas::Health::TriageTeams,
      Swagger::Schemas::Health::Folders,
      Swagger::Schemas::Health::Messages,
      Swagger::Schemas::Health::Meta,
      Swagger::Schemas::Health::Links,
      Swagger::Schemas::Errors,
      self
    ].freeze

    def index
      render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
    end
  end
end
