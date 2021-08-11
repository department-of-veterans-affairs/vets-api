# frozen_string_literal: true

require 'appeals_api/health_checker'

module AppealsApi
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    def decision_reviews
      render json: {
        meta: {
          versions: decision_reviews_versions
        }
      }
    end

    def appeals_status
      render json: {
        meta: {
          versions: [
            {
              version: '0.0.1',
              internal_only: true,
              status: VERSION_STATUS[:current],
              path: '/services/appeals/docs/v0/api',
              healthcheck: '/services/appeals/v0/healthcheck'
            }
          ]
        }
      }
    end

    def healthcheck
      render json: {
        description: 'Appeals API health check',
        status: 'UP',
        time: Time.zone.now.to_formatted_s(:iso8601)
      }
    end

    def appeals_status_upstream_healthcheck
      health_checker = AppealsApi::HealthChecker.new
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: 'Appeals API upstream health check',
        status: health_checker.appeals_services_are_healthy? ? 'UP' : 'DOWN',
        time: time,
        details: {
          name: 'All upstream services',
          upstreamServices: AppealsApi::HealthChecker::APPEALS_SERVICES.map do |service|
                              upstream_service_details(service, health_checker, time)
                            end
        }
      }, status: health_checker.appeals_services_are_healthy? ? 200 : 503
    end

    def decision_reviews_upstream_healthcheck
      health_checker = AppealsApi::HealthChecker.new
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: 'Appeals API upstream health check',
        status: health_checker.decision_reviews_services_are_healthy? ? 'UP' : 'DOWN',
        time: time,
        details: {
          name: 'All upstream services',
          upstreamServices: AppealsApi::HealthChecker::DECISION_REVIEWS_SERVICES.map do |service|
                              upstream_service_details(service, health_checker, time)
                            end
        }
      }, status: health_checker.decision_reviews_services_are_healthy? ? 200 : 503
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
          time: time
        }
      }
    end

    def decision_reviews_versions
      if beta_enabled?
        [
          decision_reviews_v1.merge,
          decision_reviews_v2.merge({ status: VERSION_STATUS[:previous] }),
          decision_reviews_v2_beta
        ]
      else
        [
          decision_reviews_v1,
          decision_reviews_v2
        ]
      end
    end

    def decision_reviews_v1
      {
        version: '1.0.0',
        internal_only: true,
        status: VERSION_STATUS[:previous],
        path: '/services/appeals/docs/v1/decision_reviews',
        healthcheck: '/services/appeals/v1/healthcheck'
      }
    end

    def decision_reviews_v2
      {
        version: '2.0.0',
        internal_only: true,
        status: VERSION_STATUS[:current],
        path: '/services/appeals/docs/v2/decision_reviews',
        healthcheck: '/services/appeals/v2/healthcheck'
      }
    end

    def decision_reviews_v2_beta
      {
        version: '2.0.0-rswag',
        internal_only: true,
        status: VERSION_STATUS[:current],
        path: '/services/appeals/docs/v2/decision_reviews_beta',
        healthcheck: '/services/appeals/v2/healthcheck'
      }
    end

    def beta_enabled?
      Settings.modules_appeals_api.documentation.path_enabled_flag
    end
  end
end
