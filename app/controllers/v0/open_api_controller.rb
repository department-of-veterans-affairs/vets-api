# frozen_string_literal: true

module V0
  class OpenApiController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate

    class << self
      def openapi_path
        Rails.public_path.join('openapi.json')
      end

      def openapi_spec
        path = openapi_path
        return unless File.exist?(path)

        mtime = File.mtime(path).to_i
        if defined?(@openapi_spec_mtime) && @openapi_spec_mtime == mtime && @openapi_spec
          return @openapi_spec
        end

        @openapi_spec_mtime = mtime
        @openapi_spec = JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        Rails.logger.error("Invalid openapi.json: #{e.message}")
        nil
      end
    end

    def index
      spec = self.class.openapi_spec

      if spec
        # Clone the spec so we can modify servers without affecting the cached version
        response_spec = spec.dup
        response_spec['servers'] = [{ 'url' => request.base_url }]
        render json: response_spec
      else
        render json: { error: 'OpenAPI specification not found' }, status: :not_found
      end
    end
  end
end
