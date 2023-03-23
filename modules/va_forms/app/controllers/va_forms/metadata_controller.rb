# frozen_string_literal: true

require 'va_forms/health_checker'

module VAForms
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)
    include HealthChecker::Constants

    def index
      render json: {
        meta: {
          versions: [
            {
              version: '0.0.1',
              internal_only: false,
              status: VERSION_STATUS[:current],
              path: '/services/va_forms/docs/v0/api',
              healthcheck: '/services/va_forms/v0/healthcheck'
            }
          ]
        }
      }
    end

    def healthcheck
      render json: {
        description: HEALTH_DESCRIPTION,
        status: 'UP',
        time: Time.zone.now.to_formatted_s(:iso8601)
      }
    end

    def upstream_healthcheck
      health_checker = VAForms::HealthChecker.new
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: HEALTH_DESCRIPTION_UPSTREAM,
        status: health_checker.services_are_healthy? ? 'UP' : 'DOWN',
        time:,
        details: {
          name: 'All upstream services',
          upstreamServices: VAForms::HealthChecker::SERVICES.map do |service|
                              upstream_service_details(service, health_checker, time)
                            end
        }
      }, status: health_checker.services_are_healthy? ? 200 : 503
    end

    private

    def upstream_service_details(service_name, health_checker, time)
      healthy = health_checker.healthy_service?(service_name)

      {
        description: service_name.titleize,
        status: healthy ? 'UP' : 'DOWN',
        details: {
          name: service_name.titleize,
          statusCode: healthy ? 200 : 503,
          status: healthy ? 'OK' : 'Unavailable',
          time:
        }
      }
    end
  end
end
