# frozen_string_literal: true

module VaFacilities
  class MetadataController < ::ApplicationController
    skip_before_action(:authenticate)

    def index
      render json: {
        meta: [
          {
            version: '1.0.0',
            internal_only: false,
            status: VERSION_STATUS[:dra],
            source: 'https://api.va.gov/services/va_facilities/docs/v1/api',
            dev_source: 'https://dev-api.va.gov/services/va_facilities/docs/v1/api',
            staging_source: 'https://staging-api.va.gov/services/va_facilities/docs/v1/api'
          },
          {
            version: '0.0.1',
            internal_only: true,
            status: VERSION_STATUS[:cur],
            source: 'https://api.va.gov/services/va_facilities/docs/v0/api',
            dev_source: 'https://dev-api.va.gov/services/va_facilities/docs/v0/api',
            staging_source: 'https://staging-api.va.gov/services/va_facilities/docs/v0/api'
          }
        ]
      }
    end
    end
end
