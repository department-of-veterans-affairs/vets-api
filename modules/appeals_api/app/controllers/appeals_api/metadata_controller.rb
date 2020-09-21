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
          versions: [
            {
              version: '1.0.0',
              internal_only: true,
              status: VERSION_STATUS[:current],
              path: '/services/appeals/docs/v1/decision_reviews',
              healthcheck: '/services/appeals/v1/healthcheck'
            }
          ]
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

      health_checker = AppealsApi::HealthChecker.new
      render json: {
        data: {
          id: 'appeals_healthcheck',
          type: 'appeals_healthcheck',
          attributes: {
            healthy: health_checker.services_are_healthy?,
            date: Time.zone.now.to_formatted_s(:iso8601),
            caseflow: {
              healthy: health_checker.caseflow_is_healthy?
            }
          }
        }
      }.to_json
    end
  end
end
