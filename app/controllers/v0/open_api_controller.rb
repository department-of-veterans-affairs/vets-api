# frozen_string_literal: true

module V0
  class OpenApiController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate

    def index
      spec = openapi_spec

      if spec
        spec['servers'] = [{ 'url' => request.base_url }]
        render json: spec, content_type: 'application/vnd.oai.openapi+json'
      else
        render json: { error: 'OpenAPI specification not found' }, status: :not_found
      end
    end

    private

    def openapi_spec
      path = Rails.public_path.join('openapi.json')
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
