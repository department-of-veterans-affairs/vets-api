# frozen_string_literal: true

module VaForms
  class MetadataController < ::ApplicationController
    skip_before_action(:authenticate)

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
      if VaForms::Form.count.positive?
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
          id: 'va_forms_healthcheck',
          type: 'va_forms_healthcheck',
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
            title: 'VA Form API Unavailable',
            detail: 'VA Forms API is currently unavailable.',
            code: '503',
            status: '503'
          }
        ]
      }.to_json
    end
  end
end
