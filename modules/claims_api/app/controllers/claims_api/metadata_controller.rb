# frozen_string_literal: true

module ClaimsApi
  class MetadataController < ::ApplicationController
    skip_before_action(:authenticate)

    def index
      render json: {
        meta: [
          {
            version: '1.0.0',
            internal_only: false,
            status: VERSION_STATUS[:draft],
            path: '/services/claims/docs/v1/api'
          },
          {
            version: '0.0.1',
            internal_only: true,
            status: VERSION_STATUS[:current],
            path: '/services/claims/docs/v0/api'
          }
        ]
      }
    end
  end
end
