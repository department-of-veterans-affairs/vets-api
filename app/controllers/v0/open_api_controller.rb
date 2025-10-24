# frozen_string_literal: true

module V0
  class OpenApiController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate

    def index
      path = Rails.public_path.join('openapi.json')
      unless File.exist?(path)
        render json: { error: 'OpenAPI specification not found' }, status: :not_found
        return
      end

      spec = JSON.parse(File.read(path))
      spec['servers'] = [{ 'url' => request.base_url }]

      render json: spec, content_type: 'application/vnd.oai.openapi+json'
    rescue JSON::ParserError
      render json: { error: 'OpenAPI specification invalid' }, status: :unprocessable_entity
    end
  end
end
