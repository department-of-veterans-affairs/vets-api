# frozen_string_literal: true

require 'appeals_api/health_checker'

module AppealsApi
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)
    before_action :set_default_headers

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

    def mail_status_upstream_healthcheck
      mail_status_code = proc do
        health_checker.mail_services_are_healthy? ? 200 : 503
      rescue => e
        Rails.logger.error('AppealsApi Mail Status Healthcheck error', status: e.status, message: e.body)
        503
      end

      render_upstream_services_response(
        health_checker.mail_services_are_healthy?,
        AppealsApi::HealthChecker::MAIL_SERVICES,
        mail_status_code.call
      )
    end

    def appeals_status_upstream_healthcheck
      appeals_status_code = proc do
        health_checker.appeals_services_are_healthy? ? 200 : 503
      rescue => e
        Rails.logger.error('AppealsApi Appeals Status Healthcheck error', status: e.status, message: e.body)
        503
      end

      render_upstream_services_response(
        health_checker.appeals_services_are_healthy?,
        AppealsApi::HealthChecker::APPEALS_SERVICES,
        appeals_status_code.call
      )
    end

    def decision_reviews_upstream_healthcheck
      decision_reviews_status_code = proc do
        health_checker.decision_reviews_services_are_healthy? ? 200 : 503
      rescue => e
        Rails.logger.error('AppealsApi Decision Reviews Healthcheck error', status: e.status, message: e.body)
        503
      end

      render_upstream_services_response(
        health_checker.decision_reviews_services_are_healthy?,
        AppealsApi::HealthChecker::DECISION_REVIEWS_SERVICES,
        decision_reviews_status_code.call
      )
    end

    private

    def set_default_headers
      AppealsApi::ApplicationController::DEFAULT_HEADERS.each { |k, v| response.headers[k] = v }
    end

    def health_checker
      @health_checker ||= AppealsApi::HealthChecker.new
    end

    def render_upstream_services_response(services_are_healthy, services, status_code)
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: 'Appeals API upstream health check',
        status: services_are_healthy ? 'UP' : 'DOWN',
        time:,
        details: {
          name: 'All upstream services',
          upstreamServices: services.map do |service|
            upstream_service_details(service, time)
          end
        }
      }, status: status_code
    end

    def upstream_service_details(service_name, time)
      healthy = health_checker.healthy_service?(service_name)

      service_details_response(service_name, healthy, time)
    rescue
      service_details_response(service_name, false, time)
    end

    def service_details_response(service_name, healthy, time)
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

    def decision_reviews_versions
      [
        decision_reviews_v1,
        decision_reviews_v2
      ]
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
  end
end
