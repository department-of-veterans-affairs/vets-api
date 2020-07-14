# frozen_string_literal: true

require 'appeals_api/health_checker'

module AppealsApi
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    def healthcheck
      if AppealsApi::HealthChecker.services_are_healthy?
        render json: healthy_service_response
      else
        render json: unhealthy_service_response,
               status: :service_unavailable
      end
    end

    private

    def healthy_service_response
      {
        data: {
          id: 'appeals_healthcheck',
          type: 'appeals_healthcheck',
          attributes: {
            healthy: true,
            date: Time.zone.now.to_formatted_s(:iso8601)
          }
        }
      }.to_json
    end

    def unhealthy_service_response
      {
        errors: [
          {
            title: 'AppealsAPI Unavailable',
            detail: 'AppealsAPI is currently unavailable.',
            code: '503',
            status: '503'
          }
        ]
      }.to_json
    end
  end
end
