# frozen_string_literal: true

module V0
  class OpenApiController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate

    def index
      openapi_file_path = Rails.public_path.join('openapi.json')

      if File.exist?(openapi_file_path)
        openapi_spec = JSON.parse(File.read(openapi_file_path))
        openapi_spec['servers'] =
          [{ 'url' => "#{Rails.application.config.protocol}://#{Rails.application.config.hostname}" }]
        render json: openapi_spec
      else
        render json: { error: 'OpenAPI specification not found' }, status: :not_found
      end
    end
  end
end
