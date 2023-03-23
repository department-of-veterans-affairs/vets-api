# frozen_string_literal: true

require 'vba_documents/health_checker'

module VBADocuments
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    def index
      render json: {
        meta: {
          versions: benefits_versions
        }
      }
    end

    def benefits_intake
      render json: {
        meta: {
          versions: benefits_versions
        }
      }
    end

    def benefits_versions
      if v2_enabled?
        [
          benefits_intake_v1.merge({ status: VERSION_STATUS[:previous] }),
          benefits_intake_v2
        ]
      else
        [
          benefits_intake_v1
        ]
      end
    end

    def benefits_intake_v1
      {
        version: '1.0.0',
        internal_only: false,
        status: VERSION_STATUS[:current],
        path: '/services/vba_documents/docs/v1/api',
        healthcheck: '/services/vba_documents/v1/healthcheck'
      }
    end

    def benefits_intake_v2
      {
        version: '2.0.0',
        internal_only: true,
        status: VERSION_STATUS[:current],
        path: '/services/vba_documents/docs/v2/api',
        healthcheck: '/services/vba_documents/v1/healthcheck'
      }
    end

    def v2_enabled?
      Settings.vba_documents.documentation.path_enabled_flag
    end

    def healthcheck
      render json: {
        description: 'VBA Documents API health check',
        status: 'UP',
        time: Time.zone.now.to_formatted_s(:iso8601)
      }
    end

    def upstream_healthcheck
      health_checker = VBADocuments::HealthChecker.new
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: 'VBA Documents API upstream health check',
        status: health_checker.services_are_healthy? ? 'UP' : 'DOWN',
        time:,
        details: {
          name: 'All upstream services',
          upstreamServices: VBADocuments::HealthChecker::SERVICES.map do |service|
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
