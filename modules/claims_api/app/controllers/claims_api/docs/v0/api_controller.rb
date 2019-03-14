# frozen_string_literal: true

module ClaimsApi
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        skip_before_action(:log_request)

        def claims
          swagger = YAML.safe_load(File.read(ClaimsApi::Engine.root.join('CLAIMS_STATUS.yml')))
          render json: swagger
        end
      end
    end
  end
end
