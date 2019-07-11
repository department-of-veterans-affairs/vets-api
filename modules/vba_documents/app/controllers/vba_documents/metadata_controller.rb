# frozen_string_literal: true

module VBADocuments
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
              path: '/services/vba_documents/docs/v1/api',
              healthcheck: '/services/vba_documents/v1/healthcheck'
            },
            {
              version: '0.0.1',
              internal_only: false,
              status: VERSION_STATUS[:previous],
              path: '/services/vba_documents/docs/v0/api',
              healthcheck: '/services/vba_documents/v0/healthcheck'
            }
          ]
        }
      }
    end

    def healthcheck
      if CentralMail::Service.service_is_up?
        healthy_service_response
      else
        unhealthy_service_response
      end
    end

    private

    def healthy_service_response
      {
        data:  {
          id: 'vba_healthcheck',
          type: 'vba_documents_healthcheck',
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
            title: 'VBA Documents API Unavailable',
            detail: 'VBA Documents API is currently unavailable.',
            code: '503',
            status: '503'
          }
        ]
      }.to_json
    end
  end
end
