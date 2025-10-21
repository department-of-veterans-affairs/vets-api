# frozen_string_literal: true

module V0
  class OpenAPIController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate

    def index
      openapi_spec = JSON.parse(Rails.public_path.join('openapi.json').read)
      render json: openapi_spec
    end
  end
end
