# frozen_string_literal: true

module ClaimsApi
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    V2_DOCS_ENABLED = Settings.claims_api.v2_docs.enabled

    def index
      render json: V2_DOCS_ENABLED ? version_2_through_previous : version_1_through_previous
    end

    private

    def version_1_through_previous
      {
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

    def version_2_through_previous # rubocop:disable Metrics/MethodLength
      {
        meta: {
          versions: [
            {
              version: '2.0.0',
              internal_only: false,
              status: VERSION_STATUS[:current],
              path: '/services/benefits/docs/v2/api',
              healthcheck: '/services/benefits/v2/healthcheck'
            },
            {
              version: '1.0.0',
              internal_only: false,
              status: VERSION_STATUS[:previous],
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
