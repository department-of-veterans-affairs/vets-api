# frozen_string_literal: true

require 'claims_api/health_checker'

module ClaimsApi
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    def index
      render json: {
        meta: {
          versions: [
            {
              version: '1.0.0',
              internal_only: false,
              status: VERSION_STATUS[:current],
              path: '/services/claims/docs/v1/api',
              healthcheck: '/services/claims/v1/healthcheck'
            },
            {
              version: '0.0.1',
              internal_only: true,
              status: VERSION_STATUS[:previous],
              path: '/services/claims/docs/v0/api',
              healthcheck: '/services/claims/v0/healthcheck'
            }
          ]
        }
      }
    end

    def healthcheck
      render json: {
        description: 'Claims API health check',
        status: 'UP',
        time: Time.zone.now.to_formatted_s(:iso8601)
      }
    end

    def upstream_healthcheck
      health_checker = ClaimsApi::HealthChecker.new
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: 'Claims API upstream health check',
        status: health_checker.services_are_healthy? ? 'UP' : 'DOWN',
        time: time,
        details: {
          name: 'All upstream services',
          upstreamServices: ClaimsApi::HealthChecker::SERVICES.map do |service|
                              upstream_service_details(service, health_checker, time)
                            end
        }
      }, status: health_checker.services_are_healthy? ? 200 : 503
    end

    private

    def upstream_service_details(service_name, health_checker, time)
      healthy = health_checker.healthy_service?(service_name)

      {
        description: service_name.upcase,
        status: healthy ? 'UP' : 'DOWN',
        details: {
          name: service_name.upcase,
          statusCode: healthy ? 200 : 503,
          status: healthy ? 'OK' : 'Unavailable',
          time: time
        }
      }
    end
  end
end
