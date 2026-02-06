# frozen_string_literal: true

module V0
  class OpenApiController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate
    before_action :restrict_to_non_production

    def index
      spec = openapi_spec

      if spec
        # Clone the spec so we can modify servers without affecting the cached version
        response_spec = spec.dup
        response_spec['servers'] = [{ 'url' => request.base_url }]
        render json: response_spec, content_type: 'application/vnd.oai.openapi+json'
      else
        render json: { error: 'OpenAPI specification not found' }, status: :not_found
      end
    end

    private

    def restrict_to_non_production
      return unless Settings.vsp_environment == 'production'

      render json: { error: 'OpenAPI specification is not available in production' }, status: :not_found
    end

    def openapi_spec
      path = Rails.root.join('config', 'openapi', 'openapi.json')
      return unless File.exist?(path)

      cache_key = "openapi_spec_#{File.mtime(path).to_i}"
      Rails.cache.fetch(cache_key) do
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        Rails.logger.error("Invalid openapi.json: #{e.message}")
        nil
      end
    end
  end
end
