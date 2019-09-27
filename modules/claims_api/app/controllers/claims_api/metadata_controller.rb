# frozen_string_literal: true

module ClaimsApi
  class MetadataController < ::ApplicationController
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
      if ClaimsApi::EVSSClaim.services_are_healthy?
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
          id: 'claims_healthcheck',
          type: 'claims_healthcheck',
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
            title: 'ClaimsAPI Unavailable',
            detail: 'ClaimsAPI is currently unavailable.',
            code: '503',
            status: '503'
          }
        ]
      }.to_json
    end
  end
end
