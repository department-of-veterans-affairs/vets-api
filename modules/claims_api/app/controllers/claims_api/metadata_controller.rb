# frozen_string_literal: true

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
              version: '2.0.0',
              internal_only: false,
              status: VERSION_STATUS[:current],
              path: '/services/claims/docs/v2/api',
              healthcheck: '/services/claims/v2/healthcheck'
            },
            {
              version: '1.0.0',
              internal_only: false,
              status: VERSION_STATUS[:deprecated],
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
  end
end
