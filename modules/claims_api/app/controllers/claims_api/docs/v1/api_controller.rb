# frozen_string_literal: true

module ClaimsApi
    module Docs
      module V1
        class ApiController < ApplicationController
          skip_before_action(:authenticate)
          skip_before_action(:log_request)
  
          include Swagger::Blocks

          swagger_root do
            key :swagger, '2.0'
            info do
            key :version, '1.0.0'
            key :title, 'Benefits Claims'
            key :description, "Veterans Benefits Administration (VBA) claims submission and status checking.\n ## Background\n Use this API to submit a Veteran's benefits claim, and to request the status of a Veteran's benefits claim.\n The Benefit Claim API passes data through to Electronic Veterans Self Service, EVSS. EVSS uses VAAFI to authenticate requests. Consumers of this API not using OAuth will need to pass the minimum VAAFI headers to this service to retrieve records."
            key :termsOfService, 'https://developer.va.gov/terms-of-service'
            contact do
                key :name, 'VA API Benefits Team'
            end
            license do
                key :name, 'MIT'
            end
            end
            tag do
            key :name, 'claims'
            key :description, 'Benefits Claims'
            externalDocs do
                key :description, 'Find more info here'
                key :url, 'https://developer.va.gov'
            end
            end
            key :host, 'api.va.gov'
            key :basePath, '/services/claims/v1'
            key :consumes, ['application/json']
            key :produces, ['application/json']
          end

          # A list of all classes that have swagger_* declarations.
          SWAGGERED_CLASSES = [
            ClaimsApi::ClaimsController,
            ClaimsApi::AutoEstablishClaim,
            self,
          ].freeze

          def index
            render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
          end
        end
      end
    end
  end
end
  