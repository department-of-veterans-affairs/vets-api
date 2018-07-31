# frozen_string_literal: true

module AppealsApi
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        skip_before_action(:log_request)

        def appeals
          swagger = YAML.safe_load(File.read(AppealsApi::Engine.root.join('APPEALS.yml')))
          render json: swagger
        end

        def claims
          swagger = YAML.safe_load(File.read(AppealsApi::Engine.root.join('EVSS_CLAIMS.yml')))
          render json: swagger
        end
      end
    end
  end
end
