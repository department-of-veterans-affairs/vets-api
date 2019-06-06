# frozen_string_literal: true

module ClaimsApi
  module Docs
    class MetadataController < ::ApplicationController
      skip_before_action(:authenticate)

      def index
        render json: {
          meta: [
            {
              name: 'Claims, Intent to File & Disability',
              version: 'V1',
              internal_only: false,
              status: VERSION_STATUS[:rel],
              source: 'https://api.va.gov/services/claims/docs/v1/api',
              dev_source: 'https://dev-api.va.gov/services/claims/docs/v1/api',
              staging_source: 'https://staging-api.va.gov/services/claims/docs/v1/api'
            },
            {
              name: 'Claims, Intent to File & Disability',
              version: 'V0',
              internal_only: true,
              status: VERSION_STATUS[:cur],
              source: 'https://api.va.gov/services/claims/docs/v0/api',
              dev_source: 'https://dev-api.va.gov/services/claims/docs/v0/api',
              staging_source: 'https://staging-api.va.gov/services/claims/docs/v0/api'
            }
          ]
        }
      end
    end
  end
end
