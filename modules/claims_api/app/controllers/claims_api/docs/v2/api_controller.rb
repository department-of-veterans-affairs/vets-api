# frozen_string_literal: true

module ClaimsApi
  module Docs
    module V2
      class ApiController < ClaimsApi::Docs::ApiController
        # rubocop:disable Layout/LineLength
        def index
          environment_directory = request.base_url == ('https://api.va.gov' || 'https://sandbox-api.va.gov') ? 'production' : 'dev'

          swagger = JSON.parse(File.read(ClaimsApi::Engine.root.join("app/swagger/claims_api/v2/#{environment_directory}/swagger.json")))
          render json: swagger
        end
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
