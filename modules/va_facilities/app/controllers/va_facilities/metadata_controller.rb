# frozen_string_literal: true

module VaFacilities
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    def index
      render json: {
        meta: {
          versions: [
            {
              version: '0.0.1',
              internal_only: false,
              status: VERSION_STATUS[:current],
              path: '/services/va_facilities/docs/v0/api',
              healthcheck: '/services/va_facilities/v0/healthcheck'
            }
          ]
        }
      }
    end
  end
end
