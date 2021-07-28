# frozen_string_literal: true

module ClaimsApi
  module Docs
    module V1
      class ApiController < ClaimsApi::Docs::ApiController
        def index
          swagger = JSON.parse(File.read(ClaimsApi::Engine.root.join('app/swagger/claims_api/v1/swagger.json')))
          render json: swagger
        end
      end
    end
  end
end
